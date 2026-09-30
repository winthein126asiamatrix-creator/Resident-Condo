import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/condo_service.dart';
import '../controllers/condo_service_controller.dart';
import '../widgets/service_widgets.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';

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
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.services.isEmpty) {
          return const Center(child: CircularProgressIndicator());
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
            key: const Key('services-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _ServicesHero(controller: controller),
              const SizedBox(height: 18),
              _TabRow(controller: controller),
              const SizedBox(height: 18),
              if (controller.tab.value == ServicesTab.catalogue)
                _Catalogue(controller: controller)
              else
                _Requests(controller: controller),
            ],
          ),
        );
      }),
    );
  }
}

class _ServicesHero extends StatelessWidget {
  const _ServicesHero({required this.controller});
  final CondoServiceController controller;

  @override
  Widget build(BuildContext context) {
    return AppHeroPanel(
      icon: Icons.room_service_rounded,
      title: 'Book a service',
      subtitle:
          '${controller.services.length} services · ${controller.openRequestCount} open requests',
      footnote: 'Services are handled by the concierge team, separately from maintenance repairs.',
      trailing: IconButton(
        tooltip: 'Refresh services',
        onPressed: controller.loadAll,
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.controller});
  final CondoServiceController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppPalette.brandTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final tab in ServicesTab.values)
            Expanded(
              child: GestureDetector(
                key: Key('services-tab-${tab.name}'),
                onTap: () => controller.selectTab(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: controller.tab.value == tab
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    tab == ServicesTab.catalogue ? 'Catalogue' : 'My requests',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: controller.tab.value == tab
                          ? AppPalette.brand
                          : AppPalette.mutedStrong,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Catalogue extends StatelessWidget {
  const _Catalogue({required this.controller});
  final CondoServiceController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.services.isEmpty) {
      return const AppStateMessage(
        title: 'No services available',
        message: 'Bookable services will appear here.',
        icon: Icons.room_service_outlined,
      );
    }
    return Column(
      children: [
        for (final service in controller.services)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
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

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconTile(
                icon: serviceIcon(service.category),
                color: AppPalette.brand,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${service.category.label} · ${service.provider}',
                      style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.currency(service.price),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    service.unit,
                    style: const TextStyle(
                      color: AppPalette.faint,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            service.description,
            style: const TextStyle(
              color: AppPalette.mutedStrong,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: AppPalette.faint,
              ),
              const SizedBox(width: 5),
              Text(
                'Needs ${service.leadTimeDays} day notice',
                style: const TextStyle(color: AppPalette.faint, fontSize: 11),
              ),
              const Spacer(),
              TextButton.icon(
                key: Key('book-service-${service.id}'),
                onPressed: () {
                  controller.selectService(service);
                  Get.toNamed(AppRoutes.serviceRequest);
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Book'),
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
    if (controller.requests.isEmpty) {
      return const AppStateMessage(
        title: 'No service requests',
        message: 'Book a service and it will show up here.',
        icon: Icons.event_note_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Active',
          count: controller.activeRequests.length,
        ),
        const SizedBox(height: 10),
        if (controller.activeRequests.isEmpty)
          const Text(
            'Nothing active right now.',
            style: TextStyle(color: AppPalette.muted, fontSize: 12),
          )
        else
          for (final request in controller.activeRequests)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RequestCard(controller: controller, request: request),
            ),
        const SizedBox(height: 16),
        AppSectionHeader(
          title: 'History',
          count: controller.pastRequests.length,
        ),
        const SizedBox(height: 10),
        for (final request in controller.pastRequests)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RequestCard(controller: controller, request: request),
          ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.controller, required this.request});
  final CondoServiceController controller;
  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        controller.selectRequest(request);
        Get.toNamed(AppRoutes.serviceRequestDetail, arguments: request);
      },
      child: Row(
        children: [
          AppIconTile(
            icon: serviceIcon(request.category),
            color: serviceStatusColor(request.status),
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.serviceName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${request.scheduledDate} · ${request.scheduledSlot}',
                  style: const TextStyle(color: AppPalette.muted, fontSize: 11),
                ),
                const SizedBox(height: 6),
                ServiceStatusPill(status: request.status),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.currency(request.price),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              if (request.rating != null)
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: AppPalette.warning,
                    ),
                    Text(
                      '${request.rating}',
                      style: const TextStyle(
                        color: AppPalette.mutedStrong,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const Icon(Icons.chevron_right_rounded, color: AppPalette.faint),
        ],
      ),
    );
  }
}
