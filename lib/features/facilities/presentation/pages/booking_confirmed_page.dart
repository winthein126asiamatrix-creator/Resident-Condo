import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../domain/entities/facility.dart';

class BookingConfirmedPage extends StatelessWidget {
  const BookingConfirmedPage({required this.reservation, super.key});

  final FacilityReservation reservation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking confirmed')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const SizedBox(height: 22),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFE6F3EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF087F5B),
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'You’re all set!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1D2B2A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your facility reservation has been confirmed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF71807D)),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE6EEEB)),
            ),
            child: Column(
              children: [
                _Line(
                  label: 'Facility',
                  value: _displayName(reservation.facilityName),
                ),
                _Line(label: 'Date', value: reservation.date),
                _Line(label: 'Time', value: reservation.time),
                _Line(label: 'Status', value: reservation.status),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Get.offAllNamed(AppRoutes.home),
            icon: const Icon(Icons.home_rounded),
            label: const Text('Done'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF71807D)),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

String _displayName(String name) {
  if (name == 'Fitness Centre') {
    return 'Gym';
  }
  if (name == 'Rooftop BBQ') {
    return 'BBQ Area';
  }
  return name;
}
