import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:test/app/routes/app_routes.dart';
import 'package:test/app/theme/app_theme.dart';
import 'package:test/core/services/photo_picker.dart';
import 'package:test/core/theme/app_palette.dart';
import 'package:test/features/maintenance/domain/entities/maintenance_request.dart';
import 'package:test/features/maintenance/presentation/bindings/maintenance_binding.dart';
import 'package:test/features/maintenance/presentation/controllers/maintenance_controller.dart';
import 'package:test/features/maintenance/presentation/pages/create_maintenance_request_page.dart';
import 'package:test/features/maintenance/presentation/pages/maintenance_page.dart';
import 'package:test/core/widgets/app_image_preview.dart';
import 'package:test/features/maintenance/presentation/pages/maintenance_detail_page.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  /// Boots a minimal app containing only the maintenance flow so the test does
  /// not have to walk through the splash and the home shell.
  Future<MaintenanceController> pumpMaintenanceApp(
    WidgetTester tester, {
    PhotoPicker? photoPicker,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: const MaintenancePage(),
        initialBinding: MaintenanceBinding(),
        getPages: [
          GetPage<dynamic>(
            name: AppRoutes.maintenanceCreate,
            page: () => CreateMaintenanceRequestPage(photoPicker: photoPicker),
          ),
          GetPage<dynamic>(
            name: AppRoutes.maintenanceDetail,
            page: () => MaintenanceDetailPage(
              request: Get.arguments as MaintenanceRequest,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return Get.find<MaintenanceController>();
  }

  /// Brings [target] on screen. The form is a single scroll view, so the
  /// target is always built and this only needs to scroll it into the
  /// viewport before it is tapped.
  Future<void> scrollFormTo(WidgetTester tester, Finder target) async {
    expect(
      target,
      findsWidgets,
      reason: 'the whole form must stay mounted so errors are not dropped',
    );
    await tester.ensureVisible(target.first);
    await tester.pumpAndSettle();
  }

  Future<void> openRequestForm(WidgetTester tester) async {
    final cta = find.byKey(const Key('add-maintenance-request'));
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pumpAndSettle();
  }

  /// Writes a real, decodable PNG to a temp folder and returns its path, so the
  /// preview goes through the same `Image.file` path as the app.
  String writeTempPhoto() {
    final directory = Directory.systemTemp.createTempSync('maintenance-photo');
    addTearDown(() => directory.deleteSync(recursive: true));
    return (File(
      '${directory.path}${Platform.pathSeparator}leak.png',
    )..writeAsBytesSync(base64Decode(_onePixelPng))).path;
  }

  /// Runs the real attach flow: the resident taps the button, picks a source
  /// from the sheet, and the platform picker is stood in for by [picker].
  Future<void> attachPhoto(
    WidgetTester tester,
    PhotoPicker picker, {
    ImageSource source = ImageSource.gallery,
  }) async {
    await scrollFormTo(tester, find.text('Attach photo'));
    await tester.tap(find.text('Attach photo'));
    await tester.pumpAndSettle();
    final sourceKey = source == ImageSource.camera
        ? const Key('photo-source-camera')
        : const Key('photo-source-gallery');
    await tester.tap(find.byKey(sourceKey));
    await tester.pumpAndSettle();
  }

  testWidgets('the maintenance list exposes a prominent new request CTA', (
    tester,
  ) async {
    await pumpMaintenanceApp(tester);

    expect(find.byType(MaintenancePage), findsOneWidget);
    final cta = find.byKey(const Key('add-maintenance-request'));
    expect(cta, findsOneWidget);
    expect(find.text('New Maintenance Request'), findsOneWidget);
    expect(
      find.descendant(of: cta, matching: find.byIcon(Icons.handyman_rounded)),
      findsOneWidget,
    );
    // It is the page CTA now, not a floating action button.
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.byType(CreateMaintenanceRequestPage), findsOneWidget);
  });

  testWidgets('the request form uses a custom app bar and sectioned fields', (
    tester,
  ) async {
    await pumpMaintenanceApp(tester);
    await openRequestForm(tester);

    expect(find.text('New Request'), findsOneWidget);
    expect(find.text('Tell us what needs attention'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);

    expect(find.text('Request details'), findsOneWidget);
    expect(find.byKey(const Key('maintenance-title')), findsOneWidget);
    expect(find.byKey(const Key('maintenance-description')), findsOneWidget);
    expect(find.text('Priority'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);

    await scrollFormTo(tester, find.text('Location & schedule'));
    expect(find.byKey(const Key('maintenance-location')), findsOneWidget);
    expect(find.byKey(const Key('maintenance-date')), findsOneWidget);
    expect(find.byKey(const Key('maintenance-time')), findsOneWidget);
  });

  testWidgets('the priority choice is reachable and updates the selection', (
    tester,
  ) async {
    await pumpMaintenanceApp(tester);
    await openRequestForm(tester);

    // Medium is preselected.
    expect(_isPrioritySelected(tester, MaintenancePriority.medium), isTrue);
    expect(_isPrioritySelected(tester, MaintenancePriority.high), isFalse);

    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();

    expect(
      _isPrioritySelected(tester, MaintenancePriority.high),
      isTrue,
      reason: 'tapping an option must select it',
    );
    expect(_isPrioritySelected(tester, MaintenancePriority.medium), isFalse);
  });

  testWidgets('submitting an empty form surfaces the field validation', (
    tester,
  ) async {
    final controller = await pumpMaintenanceApp(tester);
    final before = controller.requests.length;
    await openRequestForm(tester);

    await scrollFormTo(
      tester,
      find.byKey(const Key('submit-maintenance-request')),
    );
    await tester.tap(find.byKey(const Key('submit-maintenance-request')));
    await tester.pumpAndSettle();

    await scrollFormTo(tester, find.byKey(const Key('maintenance-title')));
    expect(find.text('Title is required'), findsOneWidget);
    expect(find.text('Description is required'), findsOneWidget);

    await scrollFormTo(tester, find.byKey(const Key('maintenance-location')));
    expect(find.text('Location is required'), findsOneWidget);

    // Nothing was submitted and we stay on the form.
    expect(find.byType(CreateMaintenanceRequestPage), findsOneWidget);
    expect(controller.requests, hasLength(before));
  });

  testWidgets('a valid request is submitted and lands in the list', (
    tester,
  ) async {
    final picker = _FakePhotoPicker();
    final path = writeTempPhoto();
    picker.results[ImageSource.gallery] = PhotoPickResult.success(
      AttachedPhoto(path: path, name: 'kitchen-sink.png'),
    );
    final controller = await pumpMaintenanceApp(tester, photoPicker: picker);
    final before = controller.requests.length;
    await openRequestForm(tester);

    await tester.enterText(
      find.byKey(const Key('maintenance-title')),
      'Kitchen tap is leaking',
    );
    await tester.enterText(
      find.byKey(const Key('maintenance-location')),
      'Kitchen',
    );
    await tester.enterText(
      find.byKey(const Key('maintenance-description')),
      'Water keeps pooling under the sink since yesterday evening.',
    );
    await tester.pumpAndSettle();

    // Optional attachments and priority keep working.
    await attachPhoto(tester, picker);
    expect(find.byKey(const Key('maintenance-photo-0')), findsOneWidget);

    await scrollFormTo(tester, find.text('High'));
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();

    await scrollFormTo(
      tester,
      find.byKey(const Key('submit-maintenance-request')),
    );
    await tester.tap(find.byKey(const Key('submit-maintenance-request')));
    // Let the success snack bar come and go so no timer outlives the test.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // We are back on the list and the new request is on top.
    expect(find.byType(MaintenancePage), findsOneWidget);
    expect(controller.requests, hasLength(before + 1));

    final created = controller.requests.first;
    expect(created.title, 'Kitchen tap is leaking');
    expect(created.location, 'Kitchen');
    expect(created.priority, MaintenancePriority.high);
    expect(created.photoCount, 1);
    // The picked file is prepared for the request rather than uploaded.
    expect(created.photoNames, contains('kitchen-sink.png'));
    expect(created.status, MaintenanceStatus.submitted);
    expect(find.text('Kitchen tap is leaking'), findsWidgets);
  });

  testWidgets('attaching a photo previews it and asks for gallery or camera', (
    tester,
  ) async {
    final picker = _FakePhotoPicker();
    final path = writeTempPhoto();
    picker.results[ImageSource.camera] = PhotoPickResult.success(
      AttachedPhoto(path: path, name: 'from-camera.png'),
    );
    await pumpMaintenanceApp(tester, photoPicker: picker);
    await openRequestForm(tester);

    // Nothing is attached before the resident picks anything.
    expect(find.byKey(const Key('maintenance-photo-0')), findsNothing);
    expect(find.byKey(const Key('maintenance-photo-count')), findsNothing);

    await attachPhoto(tester, picker, source: ImageSource.camera);

    expect(picker.sources, [ImageSource.camera]);
    expect(find.byKey(const Key('maintenance-photo-0')), findsOneWidget);
    expect(find.byKey(const Key('maintenance-photo-count')), findsOneWidget);
    expect(find.text('1 photo attached'), findsOneWidget);
    // The preview is the real picked file, not a stand-in icon.
    expect(
      find.descendant(
        of: find.byKey(const Key('maintenance-photo-0')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an attached photo can be removed again', (tester) async {
    final picker = _FakePhotoPicker();
    final path = writeTempPhoto();
    picker.results[ImageSource.gallery] = PhotoPickResult.success(
      AttachedPhoto(path: path, name: 'first.png'),
    );
    final controller = await pumpMaintenanceApp(tester, photoPicker: picker);
    await openRequestForm(tester);

    await attachPhoto(tester, picker);
    await attachPhoto(tester, picker);
    expect(find.byKey(const Key('maintenance-photo-0')), findsOneWidget);
    expect(find.byKey(const Key('maintenance-photo-1')), findsOneWidget);
    expect(find.text('2 photos attached'), findsOneWidget);

    // Drop the first one; the second keeps its own slot in the grid.
    await tester.tap(find.byKey(const Key('maintenance-photo-remove-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('maintenance-photo-1')), findsNothing);
    expect(find.byKey(const Key('maintenance-photo-0')), findsOneWidget);
    expect(find.text('1 photo attached'), findsOneWidget);

    // And the removal is what gets submitted, not the dropped photo.
    await tester.enterText(
      find.byKey(const Key('maintenance-title')),
      'Window will not close',
    );
    await tester.enterText(
      find.byKey(const Key('maintenance-description')),
      'The handle snapped off last week.',
    );
    await tester.enterText(
      find.byKey(const Key('maintenance-location')),
      'Bedroom',
    );
    await tester.pumpAndSettle();
    await scrollFormTo(
      tester,
      find.byKey(const Key('submit-maintenance-request')),
    );
    await tester.tap(find.byKey(const Key('submit-maintenance-request')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(controller.requests.first.photoNames, hasLength(1));
  });

  testWidgets('a denied permission and a cancelled picker leave the form', (
    tester,
  ) async {
    final picker = _FakePhotoPicker();
    // The camera permission is refused on this device.
    picker.results[ImageSource.camera] = const PhotoPickResult.failure(
      'Camera access is off. Enable it in your device settings to take a photo.',
    );
    // The resident opens the gallery and backs out again.
    picker.results[ImageSource.gallery] = const PhotoPickResult.cancelled();
    await pumpMaintenanceApp(tester, photoPicker: picker);
    await openRequestForm(tester);

    await attachPhoto(tester, picker, source: ImageSource.camera);
    expect(find.byKey(const Key('maintenance-photo-0')), findsNothing);
    expect(find.textContaining('Camera access is off'), findsOneWidget);

    await attachPhoto(tester, picker);
    expect(picker.sources, [ImageSource.camera, ImageSource.gallery]);
    expect(find.byKey(const Key('maintenance-photo-0')), findsNothing);
    // The form is still usable after both outcomes.
    expect(find.byType(CreateMaintenanceRequestPage), findsOneWidget);
    expect(find.byKey(const Key('submit-maintenance-request')), findsOneWidget);
  });

  testWidgets('the submit CTA stays reachable with the keyboard open', (
    tester,
  ) async {
    await pumpMaintenanceApp(tester);
    await openRequestForm(tester);

    // Simulate a phone keyboard covering roughly the lower third of the screen.
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final submit = find.byKey(const Key('submit-maintenance-request'));
    expect(submit, findsOneWidget);

    // The CTA can still be scrolled into the visible area above the keyboard.
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(submit.hitTestable(), findsOneWidget);

    // And the form is still interactive above the keyboard.
    await tester.ensureVisible(find.byKey(const Key('maintenance-title')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('maintenance-title')),
      'Balcony door will not lock',
    );
    await tester.pumpAndSettle();
    expect(find.text('Balcony door will not lock'), findsOneWidget);
  });

  testWidgets('the submit label sits in the middle of the button', (
    tester,
  ) async {
    await pumpMaintenanceApp(tester);
    await openRequestForm(tester);
    await scrollFormTo(
      tester,
      find.byKey(const Key('submit-maintenance-request')),
    );

    // The button is full width, so the label must be centred in it rather than
    // pushed to the right by the leading icon.
    final button = tester.getRect(
      find.byKey(const Key('submit-maintenance-request')),
    );
    final label = tester.getRect(find.text('Submit Request'));
    expect(
      (label.center.dx - button.center.dx).abs(),
      lessThan(1.5),
      reason: 'the label should be visually centred',
    );
  });

  /// Scrolls the details page until [target] is on screen. The list is lazy, so
  /// anything below the fold has to be scrolled to before it can be found.
  Future<void> scrollDetailsTo(WidgetTester tester, Finder target) async {
    final list = find
        .descendant(
          of: find.byKey(const Key('maintenance-detail-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(target, 200, scrollable: list);
    await tester.pumpAndSettle();
  }

  group('request details attachments', () {
    /// Books a request with one real photo attached and opens its details.
    Future<MaintenanceRequest> bookWithPhoto(
      WidgetTester tester, {
      required PhotoPicker picker,
    }) async {
      final controller = await pumpMaintenanceApp(tester, photoPicker: picker);
      await openRequestForm(tester);
      await tester.enterText(
        find.byKey(const Key('maintenance-title')),
        'Balcony door will not lock',
      );
      await tester.enterText(
        find.byKey(const Key('maintenance-description')),
        'The latch snapped and the door no longer closes.',
      );
      await tester.enterText(
        find.byKey(const Key('maintenance-location')),
        'Balcony',
      );
      await tester.pumpAndSettle();

      await attachPhoto(tester, picker);
      await scrollFormTo(
        tester,
        find.byKey(const Key('submit-maintenance-request')),
      );
      await tester.tap(find.byKey(const Key('submit-maintenance-request')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final created = controller.requests.first;
      // The picked file is carried through to the request, not just its name.
      expect(created.photoNames, hasLength(1));
      expect(created.photoPaths, hasLength(1));
      expect(created.photoPaths.first, isNotEmpty);

      await tester.tap(find.text(created.title));
      await tester.pumpAndSettle();
      expect(find.byType(MaintenanceDetailPage), findsOneWidget);
      return created;
    }

    testWidgets('an attached photo is shown on the details page', (
      tester,
    ) async {
      final picker = _FakePhotoPicker();
      picker.results[ImageSource.gallery] = PhotoPickResult.success(
        AttachedPhoto(path: writeTempPhoto(), name: 'balcony-latch.png'),
      );

      await bookWithPhoto(tester, picker: picker);

      // The attachment section sits below the fold on a phone.
      await scrollDetailsTo(tester, find.byKey(const Key('request-photo-0')));

      expect(find.text('Attachment'), findsOneWidget);
      expect(find.byKey(const Key('request-photo-0')), findsOneWidget);
      expect(find.text('balcony-latch.png'), findsOneWidget);
      // The real file is rendered, not a placeholder.
      expect(
        find.descendant(
          of: find.byKey(const Key('request-photo-0')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(find.text('Image unavailable'), findsNothing);
    });

    testWidgets('tapping the photo opens a preview that can be closed', (
      tester,
    ) async {
      final picker = _FakePhotoPicker();
      picker.results[ImageSource.gallery] = PhotoPickResult.success(
        AttachedPhoto(path: writeTempPhoto(), name: 'balcony-latch.png'),
      );
      await bookWithPhoto(tester, picker: picker);

      await scrollDetailsTo(tester, find.byKey(const Key('request-photo-0')));
      await tester.tap(find.byKey(const Key('request-photo-0')));
      await tester.pumpAndSettle();

      // Full screen preview, with a way out.
      expect(find.byKey(const Key('image-viewer-close')), findsOneWidget);
      // Pinch to zoom comes from Flutter's own InteractiveViewer.
      expect(find.byType(InteractiveViewer), findsOneWidget);

      await tester.tap(find.byKey(const Key('image-viewer-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('image-viewer-close')), findsNothing);
      expect(find.byType(MaintenanceDetailPage), findsOneWidget);
    });

    testWidgets('a request without a photo shows no image container', (
      tester,
    ) async {
      await pumpMaintenanceApp(tester);
      // maintenance-002 has no attachments.
      await tester.tap(find.text('AC not cooling'));
      await tester.pumpAndSettle();

      expect(find.byType(MaintenanceDetailPage), findsOneWidget);
      await scrollDetailsTo(tester, find.text('No photos attached'));
      expect(find.text('No photos attached'), findsOneWidget);
      expect(find.byType(AppImagePreview), findsNothing);
      expect(find.text('Image unavailable'), findsNothing);
    });
  });

  group('request progress timeline', () {
    /// Opens the details of a seeded request by its title.
    ///
    /// The list is lazy, so the card has to be scrolled into the viewport
    /// before it can be found and tapped.
    Future<void> openDetails(WidgetTester tester, String title) async {
      await pumpMaintenanceApp(tester);
      final list = find
          .descendant(
            of: find.byKey(const Key('maintenance-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(find.text(title), 200, scrollable: list);
      await tester.pumpAndSettle();
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byType(MaintenanceDetailPage), findsOneWidget);
    }

    testWidgets('every step number is centred inside its circle', (
      tester,
    ) async {
      // 'Leaking kitchen sink' is in progress, so steps 1 and 2 are done and
      // 3 and 4 still show their number.
      await openDetails(tester, 'Leaking kitchen sink');
      await scrollDetailsTo(tester, find.text('Request progress'));

      for (final index in [2, 3]) {
        final circle = tester.getRect(find.byKey(Key('progress-step-$index')));
        final number = tester.getRect(
          find.descendant(
            of: find.byKey(Key('progress-step-$index')),
            matching: find.text('${index + 1}'),
          ),
        );
        expect(
          (number.center.dx - circle.center.dx).abs(),
          lessThan(1),
          reason: 'step ${index + 1} number must be centred horizontally',
        );
        expect(
          (number.center.dy - circle.center.dy).abs(),
          lessThan(1),
          reason: 'step ${index + 1} number must be centred vertically',
        );
        // And it must not spill outside the circle.
        expect(number.left, greaterThanOrEqualTo(circle.left));
        expect(number.right, lessThanOrEqualTo(circle.right));
        expect(circle.width, circle.height);
      }

      // All four circles share one diameter.
      final widths = [
        for (var index = 0; index < MaintenanceStatus.values.length; index++)
          tester.getSize(find.byKey(Key('progress-step-$index'))).width,
      ];
      expect(widths.toSet(), hasLength(1));
    });

    testWidgets('completed, current and upcoming steps look different', (
      tester,
    ) async {
      // 'Hallway light flickering' is assigned, so step 1 is done, step 2 is
      // current and steps 3 and 4 are upcoming.
      await openDetails(tester, 'Hallway light flickering');
      await scrollDetailsTo(tester, find.text('Request progress'));

      // A completed step shows a tick rather than a number.
      expect(
        find.descendant(
          of: find.byKey(const Key('progress-step-0')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
        reason: 'a completed step is marked with a tick',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('progress-step-0')),
          matching: find.text('1'),
        ),
        findsNothing,
      );

      // The current step is more prominent than the ones after it: it has the
      // brand tint behind it and a heavier ring.
      final current = _circleDecoration(tester, 1);
      expect(current.color, AppPalette.brandTint);
      expect((current.border?.top.width ?? 0), greaterThan(1.5));

      // Upcoming steps stay neutral but still show their number.
      for (final index in [2, 3]) {
        expect(
          find.descendant(
            of: find.byKey(Key('progress-step-$index')),
            matching: find.text('${index + 1}'),
          ),
          findsOneWidget,
        );
        final decoration = _circleDecoration(tester, index);
        expect(decoration.color, AppPalette.surface);
        expect(decoration.border?.top.color, AppPalette.border);
      }
    });

    testWidgets('the timeline follows the request status', (tester) async {
      // 'Hallway light flickering' is assigned: step 1 is done, step 2 current.
      await openDetails(tester, 'Hallway light flickering');
      await scrollDetailsTo(tester, find.text('Request progress'));
      expect(
        _circleDecoration(tester, 0).color,
        AppPalette.brand,
        reason: 'the finished step is filled',
      );
      expect(
        _circleDecoration(tester, 1).color,
        AppPalette.brandTint,
        reason: 'the step the request has reached is current',
      );
      expect(_circleDecoration(tester, 2).color, AppPalette.surface);

      // Moving the request forward moves the timeline rather than hardcoding
      // anything: step 2 becomes done and step 3 becomes current.
      await tester.ensureVisible(
        find.byKey(const Key('advance-maintenance-request')),
      );
      await tester.tap(find.byKey(const Key('advance-maintenance-request')));
      await tester.pumpAndSettle();
      await scrollDetailsTo(tester, find.text('Request progress'));

      expect(
        find.descendant(
          of: find.byKey(const Key('progress-step-1')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
        reason: 'the step that was current is now done',
      );
      expect(_circleDecoration(tester, 2).color, AppPalette.brandTint);
      expect(find.text('In Progress'), findsOneWidget);
    });

    testWidgets('the details page has no overflow on a small android screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await openDetails(tester, 'Hallway light flickering');
      await scrollDetailsTo(tester, find.text('Request progress'));

      // The longest status name has to wrap rather than overflow.
      expect(find.text('In Progress'), findsOneWidget);
      for (var index = 0; index < MaintenanceStatus.values.length; index++) {
        final circle = find.byKey(Key('progress-step-$index'));
        expect(circle, findsOneWidget);
        await tester.ensureVisible(circle);
        await tester.pumpAndSettle();
      }
    });
  });

  testWidgets('the flow has no overflow on a small android screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpMaintenanceApp(tester);
    // Any RenderFlex overflow is reported as a test failure.
    expect(find.byType(MaintenancePage), findsOneWidget);
    expect(find.byKey(const Key('add-maintenance-request')), findsOneWidget);

    // Scroll the whole list so every card is laid out on the narrow screen.
    final list = find
        .descendant(
          of: find.byKey(const Key('maintenance-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Your requests'),
      200,
      scrollable: list,
    );
    await tester.pumpAndSettle();
    expect(find.text('Your requests'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Leaking kitchen sink'),
      200,
      scrollable: list,
    );
    await tester.pumpAndSettle();
    expect(find.text('Leaking kitchen sink'), findsOneWidget);

    // Back to the CTA, then into the form.
    await tester.scrollUntilVisible(
      find.byKey(const Key('add-maintenance-request')),
      -200,
      scrollable: list,
    );
    await openRequestForm(tester);
    expect(find.byType(CreateMaintenanceRequestPage), findsOneWidget);
    for (final key in const [
      'maintenance-title',
      'maintenance-description',
      'maintenance-location',
      'maintenance-date',
      'maintenance-time',
      'submit-maintenance-request',
    ]) {
      final finder = find.byKey(Key(key));
      expect(
        finder,
        findsOneWidget,
        reason: '$key must render on a small phone',
      );
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }
  });
}

/// Reads the selected state of a priority option from the label colour the
/// option renders when it is active.
bool _isPrioritySelected(WidgetTester tester, MaintenancePriority priority) {
  final label = _priorityLabels[priority]!;
  final active = _priorityColors[priority]!;
  final text = tester.widget<Text>(
    find
        .descendant(
          of: find.byKey(ValueKey('priority-${priority.name}')),
          matching: find.text(label),
        )
        .first,
  );
  return text.style?.color == active;
}

const _priorityLabels = <MaintenancePriority, String>{
  MaintenancePriority.low: 'Low',
  MaintenancePriority.medium: 'Medium',
  MaintenancePriority.high: 'High',
};

const _priorityColors = <MaintenancePriority, Color>{
  MaintenancePriority.low: AppPalette.success,
  MaintenancePriority.medium: AppPalette.warning,
  MaintenancePriority.high: AppPalette.danger,
};

/// Reads the decoration of a timeline circle, so the tests can check that the
/// three states really look different.
BoxDecoration _circleDecoration(WidgetTester tester, int position) {
  final container = tester.widget<Container>(
    find.byKey(Key('progress-step-$position')),
  );
  return container.decoration! as BoxDecoration;
}

/// Stands in for the platform picker so the tests drive the real flow without
/// a device camera or gallery.
class _FakePhotoPicker implements PhotoPicker {
  _FakePhotoPicker([Map<ImageSource, PhotoPickResult>? results])
    : results = results ?? <ImageSource, PhotoPickResult>{};

  final Map<ImageSource, PhotoPickResult> results;
  final sources = <ImageSource>[];

  @override
  Future<PhotoPickResult> pick(ImageSource source) async {
    sources.add(source);
    return results[source] ?? const PhotoPickResult.cancelled();
  }
}

/// A one pixel PNG, enough for `Image.file` to decode a real preview.
const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
