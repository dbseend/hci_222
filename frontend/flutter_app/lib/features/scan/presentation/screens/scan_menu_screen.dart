import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import 'camel_price_input_screen.dart';
import 'scan_screen.dart';

class ScanMenuScreen extends StatelessWidget {
  const ScanMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Price Check'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceLight,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(icon: Icon(Icons.camera_alt), text: 'Live Scan'),
              Tab(icon: Icon(Icons.hiking), text: 'Camel Ride'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [ScanScreen(), CamelPriceInputScreen()],
        ),
      ),
    );
  }
}
