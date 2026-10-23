import "dart:io";
import "package:flutter/material.dart";
import "package:get/get.dart";
import "package:image_picker/image_picker.dart";
import "package:intl/intl.dart";

export "package:events_app/auth/auth_controller.dart";

class ThemeController extends GetxController {
  static ThemeController get to => Get.find();
  final Rx<ThemeMode> _themeMode = ThemeMode.light.obs;

  ThemeMode get themeMode => _themeMode.value;
  set themeMode(ThemeMode mode) => _themeMode.value = mode;

  void toggleTheme() => themeMode = themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
}

class SelectedDayController extends GetxController {
  static SelectedDayController get to => Get.find();
  final Rx<DateTime> _selectedDay = DateTime.now().obs;
  final df = DateFormat("yyyy-MM-dd");

  DateTime get selectedDay => _selectedDay.value;
  bool get isAtToday => df.format(selectedDay) == df.format(DateTime.now());
  set selectedDay(DateTime day) => _selectedDay.value = day;
}

class SelectedRoomController extends GetxController {
  static SelectedRoomController get to => Get.find();
  final RxString _selectedRoom = "".obs;

  String get selectedRoom => _selectedRoom.value;
  set selectedRoom(String room) => _selectedRoom.value = room;
}

class DScrollController extends GetxController {
  static DScrollController get to => Get.find();
  final _scrollController = DraggableScrollableController();
  final RxDouble _isValue = 0.0.obs;
  final RxBool _isAtMax = false.obs;

  double get isValue => _isValue.value;
  DraggableScrollableController get scrollController => _scrollController;
  bool get isAtMax => _isAtMax.value;
  set isValue(double value) => _isValue.value = value;
  set isAtMax(bool value) => _isAtMax.value = value;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(() => isAtMax = scrollController.size > 0.95);
  }
}

class ImagePickerController extends GetxController {
  static ImagePickerController get to => Get.find();
  final Rx<File> _selectedImage = Rx<File>(File(""));
  final RxBool isImageSelected = false.obs;

  File get selectedImage => _selectedImage.value;

  Future<bool> get isImageExists async => await selectedImage.exists();

  Future<void> imageEmpty() async {
    _selectedImage.value = File("");
    isImageSelected.value = false;
  }

  Future<void> selectImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      _selectedImage.value = File(pickedFile.path);
      isImageSelected.value = true;
    } else {
      _selectedImage.value = File("");
      isImageSelected.value = false;
    }
  }
}

class TextFieldsController extends GetxController {
  static TextFieldsController get to => Get.find();
  final _controller = TextEditingController();
  final RxString _getText = "".obs;

  String get getText => _getText.value;
  TextEditingController get controller => _controller;
  set setText(String text) => _getText.value = text;

  @override
  void onInit() {
    super.onInit();
    controller.addListener(() => setText = controller.text);
  }
}
