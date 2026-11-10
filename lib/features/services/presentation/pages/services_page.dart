import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';

import '../../../../core/theme/app_text_styles.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/utils/app_dates.dart';

import '../../../../core/utils/app_formatters.dart';

import '../../../../core/widgets/app_card.dart';

import '../../../../core/widgets/app_section.dart';

import '../../../../core/widgets/app_state_message.dart';

import '../../../../core/widgets/app_status_pill.dart';

import '../../domain/entities/condo_service.dart';

import '../controllers/condo_service_controller.dart';

import '../widgets/service_widgets.dart';

import '../../../../core/widgets/app_detail_app_bar.dart';

import '../../../../core/widgets/app_segmented_tabs.dart';

class ServicesPage extends GetView<CondoServiceController> {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Condo services',
        actions: [
          IconButton(
            onPressed: controller.loadAll,
            tooltip: 'Refresh services',
            icon: Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.services.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null &&
            controller.services.isEmpty) {
          return AppStateMessage(
            title: 'Unable to load services',
            message: controller.errorMessage.value!,
            icon: Icons.room_service_outlined,
            actionLabel: 'Try again',
            onAction: controller.loadAll,
          );
        }
        return RefreshIndicator(
          onRefresh: controller.loadAll,
          child: ListView(
            key: Key('services-scroll'),
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _ServicesHero(controller: controller),
              if (controller.isShowingCachedData.value) ...[
                12.h.heightBox(),
                const _OfflineNotice(),
              ],
              18.h.heightBox(),
              _TabRow(controller: controller),
              18.h.heightBox(),
              // The pill slides into the next tab, so the panel that follows it
              // across rather than swapping the instant the tap lands.
              AnimatedSwitcher(
                duration: AppSegmentedTabs.slideDuration,
                switchInCurve: AppSegmentedTabs.slideCurve,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(controller.tab.value),
                  child: controller.tab.value == ServicesTab.catalogue
                      ? _Catalogue(controller: controller)
                      : _Requests(controller: controller),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Says the services and requests on screen came from this device.
///
/// Same tokens as the cards below so it reads as part of the page rather than
/// an alert. The reconnect worker refreshes the data when the API is reachable
/// again; pulling down also retries.
class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18.r, color: tokens.muted),
          10.w.widthBox(),
          Expanded(
            child: Text(
              'Showing your saved services and requests. Pull down to try again.',
              style: TextStyle(color: tokens.muted, fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicesHero extends StatelessWidget {
  const _ServicesHero({required this.controller});
  final CondoServiceController controller;

  @override
  Widget build(BuildContext context) {
    //final tokens = AppThemeTokens.of(context);
    return AppHeroPanel(
      icon: Icons.room_service_rounded,
      title: 'Book a service',
      subtitle:
          '${controller.services.length} services · ${controller.openRequestCount} open requests',
      footnote: 'Services are handled by the concierge team, separately from maintenance repairs.',
      // trailing: IconButton(
      //   tooltip: 'Refresh services',
      //   onPressed: controller.loadAll,
      //   icon: Icon(Icons.refresh_rounded, color: tokens.brandOnDark),
      // ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.controller});
  final CondoServiceController controller;

  @override
  Widget build(BuildContext context) {
    return AppSegmentedTabs(
      keyPrefix: 'services',
      selectedIndex: controller.tab.value.index,
      onSelect: (index) => controller.selectTab(ServicesTab.values[index]),
      tabs: [
        AppSegmentedTab(
          name: 'catalogue',
          label: 'Catalogue',
          icon: Icons.grid_view_rounded,
        ),
        AppSegmentedTab(
          name: 'requests',
          label: 'My requests',
          icon: Icons.event_note_rounded,
        ),
      ],
    );
  }
}

class _Catalogue extends StatelessWidget {
  const _Catalogue({required this.controller});
  final CondoServiceController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.services.isEmpty) {
      return AppStateMessage(
        title: 'No services available',
        message: 'Bookable services will appear here.',
        icon: Icons.room_service_outlined,
      );
    }
    return Column(
      children: [
        for (final service in controller.services)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _ServiceCard(controller: controller, service: service),
          ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.controller, required this.service});
  final CondoServiceController controller;
  final CondoService service;

  void _openBooking() {
    controller.selectService(service);
    Get.toNamed(AppRoutes.serviceRequest, arguments: service.id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final styles = AppTextStyles.of(context);
    return AppCard(
      onTap: _openBooking,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconTile(
                icon: serviceIcon(service.category),
                color: tokens.brand,
                size: 46,
              ),
              12.w.widthBox(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: styles.cardTitle,
                    ),
                    3.h.heightBox(),
                    Text(
                      '${service.category.label} \u00B7 ${service.provider}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.muted, fontSize: 11.5.sp),
                    ),
                  ],
                ),
              ),
              10.w.widthBox(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _pricingLabel(service),
                    style: TextStyle(
                      color: tokens.brand,
                      fontWeight: FontWeight.w800,
                      fontSize: 16.sp,
                    ),
                  ),
                  2.h.heightBox(),
                  Text(
                    _pricingUnit(service),
                    style: TextStyle(color: tokens.faint, fontSize: 10.5.sp),
                  ),
                ],
              ),
            ],
          ),
          10.h.heightBox(),
          Text(
            service.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.mutedStrong,
              fontSize: 12.5.sp,
              height: 1.4,
            ),
          ),
          12.h.heightBox(),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 15, color: tokens.faint),
              5.w.widthBox(),
              Expanded(
                child: Text(
                  'Needs ${service.leadTimeDays} day notice',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.faint, fontSize: 11.sp),
                ),
              ),
              8.w.widthBox(),
              FilledButton.icon(
                key: Key('book-service-${service.id}'),
                onPressed: _openBooking,
                icon: Icon(Icons.add_rounded, size: 17),
                label: Text('Book'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  textStyle: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Requests extends StatelessWidget {
  const _Requests({required this.controller});
  final CondoServiceController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final active = controller.activeRequests;
    final history = controller.historyRequests;
    if (active.isEmpty &&
        history.isEmpty &&
        controller.historyTotal.value == 0 &&
        !controller.isLoading.value) {
      return AppStateMessage(
        title: 'No service requests',
        message: 'Book a service and it will show up here.',
        icon: Icons.event_note_outlined,
      );
    }
    final groups = _groupHistory(history);
    final historyCount = controller.historyTotal.value > 0
        ? controller.historyTotal.value
        : history.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: 'Active', count: active.length),
        10.h.heightBox(),
        if (active.isEmpty)
          Text(
            'Nothing active right now.',
            style: TextStyle(color: tokens.muted, fontSize: 12.sp),
          )
        else
          for (final request in active)
            Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: _RequestCard(controller: controller, request: request),
            ),
        18.h.heightBox(),
        if (history.isNotEmpty)
          AppSectionHeader(title: 'History', count: historyCount)
        else
          for (final group in groups) ...[
            _HistoryMonthHeader(label: group.label),
            8.h.heightBox(),
            for (final request in group.requests)
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: _RequestCard(controller: controller, request: request),
              ),
          ],
        if (controller.hasMoreHistory) ...[
          12.h.heightBox(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: controller.isLoadingMoreHistory.value
                  ? null
                  : controller.loadMoreHistory,
              icon: controller.isLoadingMoreHistory.value
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.expand_more_rounded, size: 18),
              label: Text(
                controller.isLoadingMoreHistory.value
                    ? 'Loading...'
                    : 'Load older requests',
              ),
              style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(48)),
            ),
          ),
        ],
      ],
    );
  }
}

List<({String label, List<ServiceRequest> requests})> _groupHistory(
  List<ServiceRequest> requests,
) {
  final groups = <String, ({String label, List<ServiceRequest> requests})>{};
  for (final request in requests) {
    final date = AppDates.parse(request.scheduledDate);
    final key = '${date.year}-${date.month}';
    final group = groups[key];
    if (group == null) {
      groups[key] = (
        label: AppDates.formatMonthYear(date),
        requests: <ServiceRequest>[request],
      );
    } else {
      group.requests.add(request);
    }
  }
  return groups.values.toList();
}

class _HistoryMonthHeader extends StatelessWidget {
  const _HistoryMonthHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: tokens.brand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          8.w.widthBox(),
          Text(
            label,
            style: TextStyle(
              color: tokens.mutedStrong,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.controller, required this.request});
  final CondoServiceController controller;
  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppCard(
      onTap: () {
        vibrateNow();
        controller.selectRequest(request);
        Get.toNamed(AppRoutes.serviceRequestDetail, arguments: request);
      },
      child: Row(
        children: [
          AppIconTile(
            icon: serviceIcon(request.category),
            color: serviceStatusColor(request.status, tokens),
            size: 42,
          ),
          12.w.widthBox(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Text(
                      request.serviceName,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Column(
                      mainAxisAlignment: .end,
                      children: [
                        Text(
                          '${request.currency} ${AppFormatters.currency(request.price)}',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
                4.h.heightBox(),
                Text(
                  '${request.scheduledDate} Â· ${request.scheduledSlot}',
                  style: TextStyle(color: tokens.muted, fontSize: 11.sp),
                ),
                6.h.heightBox(),
                Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    ServiceStatusPill(
                      status: request.status,
                      label: request.displayStatus,
                    ),
                    Icon(Icons.chevron_right_rounded, color: tokens.faint),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _pricingLabel(CondoService service) {
  switch (service.pricing.type) {
    case ServicePricingType.quote:
      return 'Request a Quote';
    case ServicePricingType.free:
      return 'Free';
    default:
      return '${service.pricing.currency} ${AppFormatters.currency(service.price)}';
  }
}

String _pricingUnit(CondoService service) {
  switch (service.pricing.type) {
    case ServicePricingType.fixed:
      return 'fixed';
    case ServicePricingType.perUnit:
      return '/ ${service.pricing.unit ?? 'unit'}';
    case ServicePricingType.perHour:
      return '/ hour';
    case ServicePricingType.quote:
      return '';
    case ServicePricingType.free:
      return '';
  }
}
