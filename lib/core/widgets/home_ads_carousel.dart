import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hather_app/core/home_ads/home_ad_launcher.dart';
import 'package:hather_app/core/home_ads/home_ads_constants.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class HomeAdsCarousel extends StatefulWidget {
  const HomeAdsCarousel({
    required this.ads,
    super.key,
  });

  final List<HomeAd> ads;

  @override
  State<HomeAdsCarousel> createState() => _HomeAdsCarouselState();
}

class _HomeAdsCarouselState extends State<HomeAdsCarousel> {
  final _pageController = PageController(viewportFraction: 0.92);
  int _index = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _scheduleAutoPlay();
  }

  @override
  void didUpdateWidget(HomeAdsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ads.length != widget.ads.length) {
      _cancelAutoPlay();
      _index = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _scheduleAutoPlay();
    }
  }

  @override
  void dispose() {
    _cancelAutoPlay();
    _pageController.dispose();
    super.dispose();
  }

  void _cancelAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  void _scheduleAutoPlay() {
    _cancelAutoPlay();
    if (widget.ads.length <= 1) return;
    _autoPlayTimer = Timer(homeAdsAutoPlayInterval, _advanceToNextAd);
  }

  void _advanceToNextAd() {
    if (!mounted || widget.ads.length <= 1) return;
    final nextIndex = (_index + 1) % widget.ads.length;
    _pageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _scheduleAutoPlay();
  }

  Future<void> _onAdTap(HomeAd ad) async {
    if (!ad.isTappable) return;

    switch (ad.actionType) {
      case HomeAdActionType.link:
        final url = ad.linkUrl?.trim();
        if (url == null || url.isEmpty) return;
        await HomeAdLauncher.openLink(url);
      case HomeAdActionType.whatsapp:
        final phone = ad.whatsappPhone?.trim();
        if (phone == null || phone.isEmpty) return;
        await HomeAdLauncher.openWhatsApp(phone);
      case HomeAdActionType.none:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ads = widget.ads;
    final pageCount = ads.isEmpty ? 1 : ads.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            l10n.adsSectionTitle,
            style: AppTextStyles.bodyStrong,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 148,
          child: PageView.builder(
            controller: _pageController,
            itemCount: pageCount,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              if (ads.isEmpty) {
                return const _AdPlaceholderCard();
              }
              final ad = ads[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _RemoteAdCard(
                  ad: ad,
                  title: ad.titleAr ?? l10n.adsSectionTitle,
                  onTap: ad.isTappable ? () => _onAdTap(ad) : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            pageCount,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _index ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _index ? AppColors.icon : AppColors.border,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdPlaceholderCard extends StatelessWidget {
  const _AdPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppColors.primary.withValues(alpha: 0.18),
              AppColors.surfaceElevated,
            ],
          ),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adsPlaceholderTitle,
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adsPlaceholderBody,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoteAdCard extends StatelessWidget {
  const _RemoteAdCard({
    required this.ad,
    required this.title,
    this.onTap,
  });

  final HomeAd ad;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = ad.imageUrl;
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: AppColors.surfaceElevated,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.icon,
                    ),
                  ),
                );
              },
              errorBuilder: (_, error, stackTrace) {
                if (kDebugMode) {
                  debugPrint('Home ad image failed: $imageUrl ($error)');
                }
                return Container(color: AppColors.surfaceElevated);
              },
            )
          else
            Container(color: AppColors.surfaceElevated),
          Container(
            alignment: AlignmentDirectional.bottomStart,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
            child: Text(
              title,
              style: AppTextStyles.bodyStrong.copyWith(
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}
