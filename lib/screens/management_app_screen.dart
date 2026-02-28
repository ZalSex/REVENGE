import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/theme.dart';
import '../utils/app_localizations.dart';
import '../screens/owner_management_screen.dart';
import '../screens/manage_users_screen.dart';

class ManagementAppScreen extends StatefulWidget {
  const ManagementAppScreen({super.key});

  @override
  State<ManagementAppScreen> createState() => _ManagementAppScreenState();
}

class _ManagementAppScreenState extends State<ManagementAppScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.darkBg,
        appBar: AppBar(
          backgroundColor: AppTheme.darkBg,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            ),
          ),
          title: Row(children: [
            Container(width: 3, height: 18,
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
            SizedBox(width: 10),
            Text(tr('management_app'),
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
          ]),
          bottom: TabBar(
            controller: _tabCtrl,
            indicatorColor: AppTheme.accentBlue,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontFamily: 'Orbitron', fontSize: 10, letterSpacing: 1),
            unselectedLabelColor: AppTheme.textMuted,
            labelColor: AppTheme.accentBlue,
            tabs: [
              Tab(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SvgPicture.string(AppSvgIcons.mobile, width: 14, height: 14,
                      colorFilter: const ColorFilter.mode(AppTheme.accentBlue, BlendMode.srcIn)),
                  SizedBox(width: 6),
                  Text(tr('manage_sender')),
                ]),
              ),
              Tab(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SvgPicture.string(AppSvgIcons.manage, width: 14, height: 14,
                      colorFilter: const ColorFilter.mode(AppTheme.accentBlue, BlendMode.srcIn)),
                  SizedBox(width: 6),
                  Text(tr('manage_users')),
                ]),
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: const [
            OwnerManagementBody(),
            ManageUsersBody(),
          ],
        ),
      ),
    );
  }
}

