import 'package:flutter/material.dart';

import 'widgets/common_app_bar.dart';
import 'widgets/edit_profile_button.dart';
import 'widgets/favorite_genres.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_stats.dart';

/// 1주차 정적인 영화 취향 프로필 화면.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '내 프로필'),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileHeader(),
              SizedBox(height: 24),
              ProfileStats(),
              SizedBox(height: 24),
              FavoriteGenres(),
              SizedBox(height: 32),
              EditProfileButton(),
            ],
          ),
        ),
      ),
    );
  }
}
