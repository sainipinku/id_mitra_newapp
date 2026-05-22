part of 'image_settings_cubit.dart';

abstract class ImageSettingsState {}

class ImageSettingsInitial extends ImageSettingsState {}

class ImageSettingsLoading extends ImageSettingsState {}

class ImageSettingsFetchLoading extends ImageSettingsState {}

class ImageSettingsFetchLoaded extends ImageSettingsState {
  final Map<String, dynamic> data;
  ImageSettingsFetchLoaded({required this.data});
}

class ImageSettingsFetchFailed extends ImageSettingsState {
  final String message;
  ImageSettingsFetchFailed({required this.message});
}

class ImageSettingsSuccess extends ImageSettingsState {
  final String message;
  final String? imageShape;
  ImageSettingsSuccess({required this.message, this.imageShape});
}

class ImageSettingsFailed extends ImageSettingsState {
  final String message;
  ImageSettingsFailed({required this.message});
}
