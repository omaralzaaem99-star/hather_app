import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:hather_app/core/widgets/app_shell_scaffold.dart';

import 'package:hather_app/core/widgets/hather_floating_bottom_nav_bar.dart';

import 'package:hather_app/l10n/app_localizations.dart';



/// User bottom shell. Branches: 0=orders, 1=home, 2=account.

class MainShell extends StatelessWidget {

  const MainShell({required this.navigationShell, super.key});



  final StatefulNavigationShell navigationShell;



  @override

  Widget build(BuildContext context) {

    final l10n = AppLocalizations.of(context);



    return AppShellScaffold(

      navigationShell: navigationShell,

      navItems: [

        ShellNavItem(

          branchIndex: 2,

          label: l10n.navAccount,

          icon: Icons.person_outline_rounded,

          activeIcon: Icons.person_rounded,

        ),

        ShellNavItem(

          branchIndex: 1,

          label: l10n.navHome,

          icon: Icons.home_outlined,

          activeIcon: Icons.home_rounded,

        ),

        ShellNavItem(

          branchIndex: 0,

          label: l10n.ordersTitle,

          icon: Icons.assignment_outlined,

          activeIcon: Icons.assignment_rounded,

        ),

      ],

    );

  }

}

