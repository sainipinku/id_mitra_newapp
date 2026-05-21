import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/components/text_filed.dart';
import 'package:idmitra/helpers/keyboard.dart';
import 'package:idmitra/models/city_model.dart';
import 'package:idmitra/models/state_model.dart';
import 'package:idmitra/screens/add_school/MapScreen.dart';
import 'package:idmitra/screens/dashboard/dashboard.dart';
import 'package:idmitra/utils/common_widgets/LogoUploadView.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';
import 'package:idmitra/utils/common_widgets/drop_down/drop_down.dart';
import 'package:http/http.dart' as http;
import 'package:idmitra/utils/navigation_utils.dart';
import '../../Widgets/CommonAppBar.dart';
import '../../components/app_theme.dart';
import '../../components/my_font_weight.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
class AddNewSchoolPage extends StatefulWidget {
  const AddNewSchoolPage({super.key});

  @override
  State<AddNewSchoolPage> createState() => _AddNewSchoolPageState();
}

class _AddNewSchoolPageState extends State<AddNewSchoolPage> {
  int currentStep = 1;
  double Lat = 0.00;
  double Long = 0.00;
  final TextEditingController schoolNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController urlController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController whatsappController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController firmNameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController pinCodeController = TextEditingController();
  TextEditingController gstController = TextEditingController();
  List<States> _states = [];
  List<City> _cities = [];
  List<States> get states => _states;
  List<City> get cities => _cities;
  States? _selectedState;
  int? stateId;
  int? cityId;
  Map<String, int> _stateMap = {};
  Map<String, int> _cityMap = {};
  Map<String, int> get stateMap => _stateMap;
  Map<String, int> get cityMap => _cityMap;
  States? get selectedState => _selectedState;
  set selectedState(States? state) {
    _selectedState = state;
    if (state != null) {

      stateId = state.id;

    }
    // notifyListeners();
  }

  City? _selectedCity;
  City? get selectedCity => _selectedCity;


  set selectedCity(City? city) {
    _selectedCity = city;
    if (city != null) {
      cityId = city.id;
    }

  }
  String selectedStateName = 'Select State';
  String selectedCityName = 'Select City';
  String profilePhotoUrl = '';
  Future<void> fetchStates() async {
    final response = await http.get(Uri.parse(Config.baseUrl + Routes.commonStates),
        headers: {"Accept": "application/json"});

    if (response.statusCode == 200) {
      StateModel stateModel = stateModelFromJson(response.body);
      _states = stateModel.list ?? [];
      _stateMap = {for (var state in _states) state.name ?? '': state.id ?? 0};
      setState(() {});
    } else {
      throw Exception('Failed to load data');
    }
  }

  Future fetchCities(int stateId) async {
    // 🔹 Step 1: Empty old data before fetching
    _cities = [];
    _cityMap = {};
    setState(() {});

    // 🔹 Step 2: Fetch new data
    final response = await http.get(
      Uri.parse(Config.baseUrl + Routes.commonCites(stateId.toString())),
      headers: {"Accept": "application/json"},
    );

    if (response.statusCode == 200) {
      CityModel cityModel = cityModelFromJson(response.body);

      // 🔹 Step 3: Save new data
      _cities = cityModel.list ?? [];
      _cityMap = {for (var city in _cities) city.name ?? '': city.id ?? 0};

      setState(() {});
    } else {
      throw Exception('Failed to load data');
    }
  }
  File? firmLogoFile;
  File? profileImageFile;
  CroppedFile? croppedProfileFile;

  CroppedFile? croppedFirmFile;
  _FromGallery(BuildContext context,bool isProfile) async {
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if(isProfile){
          profileImageFile = pickedFile != null ? File(pickedFile.path) : null;
        }else {
          firmLogoFile = pickedFile != null ? File(pickedFile.path) : null;
        }

        _cropImage(isProfile);
      });
    }
  }
  Future<void> _cropImage(bool isProfile) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: isProfile ? profileImageFile!.path : firmLogoFile!.path,
      aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: AppTheme.MainColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio4x3,
            lockAspectRatio: true,
            hideBottomControls: true),
        IOSUiSettings(
            title: 'Cropper',
            minimumAspectRatio: 1.1,
            aspectRatioLockEnabled: true,
            resetButtonHidden: true
        )
      ],
    );
    if(isProfile){
      if (profileImageFile != null) {
        if (croppedFile != null) {
          setState(() {
            croppedProfileFile = croppedFile;
          });
          final path = croppedProfileFile!.path;

        }
      }
    }else {
      if (firmLogoFile != null) {
        if (croppedFile != null) {
          setState(() {
            croppedFirmFile = croppedFile;
          });
          final path = croppedFirmFile!.path;

        }
      }
    }

  }
  _FromCamera(BuildContext context,bool isProfile) async {
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        if(isProfile){
          profileImageFile = pickedFile != null ? File(pickedFile.path) : null;
        }else {
          firmLogoFile = pickedFile != null ? File(pickedFile.path) : null;
        }

        _cropImage(isProfile);
      });
    }
  }
  void _showPicker(context,bool isProfile) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.whiteColor,
        shape: const RoundedRectangleBorder( // <-- SEE HERE
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(25.0),
          ),
        ),
        builder: (BuildContext bc) {
          return  SingleChildScrollView(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Center(
                child: Padding(padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.center,
                        child: Text('Choose Your Picher',
                            style: MyStyles.boldText(size: 14, color: AppTheme.black_Color)),
                      ),
                      InkWell(
                        onTap: (){
                          //checkCameraPermission(context);
                          _FromCamera(context,isProfile);
                          KeyboardUtil.hideKeyboard(context);
                          Navigator.of(context).pop();
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children:  [
                            SvgPicture.asset(
                              'assets/icons/camera_single.svg',
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 10.0),
                              child: Text('Camera',
                                  style: MyStyles.regularText(size: 14, color: AppTheme.black_Color)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(top: 10.0,bottom: 10.0),
                        width: MediaQuery.of(context).size.width,
                        color: AppTheme.cardBgSecColor,
                      ),
                      InkWell(
                        onTap: () async{
                          _FromGallery(context,isProfile);
                          // checkGalleryPermission(context);
                          KeyboardUtil.hideKeyboard(context);
                          Navigator.of(context).pop();
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children:  [
                            SvgPicture.asset(
                              'assets/icons/choose_from_gallery.svg',
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 10.0),
                              child: Text("Choose From Gallery",
                                  style: MyStyles.regularText(size: 14, color: AppTheme.black_Color)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(top: 10.0,bottom: 10.0),
                        width: MediaQuery.of(context).size.width,
                        color: AppTheme.cardBgSecColor,
                      ),
                      InkWell(
                        onTap: (){
                          setState((){
                            Navigator.of(context).pop();

                          });

                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children:  [
                            SvgPicture.asset(
                              'assets/icons/remove_image.svg',
                              allowDrawingOutsideViewBox:
                              true,
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 10.0),
                              child: Text('Remove Photo',
                                  style: MyStyles.regularText(size: 14, color: AppTheme.redBtnBgColor)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(top: 10.0,bottom: 10.0),
                        width: MediaQuery.of(context).size.width,
                        color: AppTheme.cardBgSecColor,
                      )

                    ],
                  ) ,)
                ,
              ),
            )
            ,
          );
        });
  }
  @override
  void initState() {
    // TODO: implement initState
    fetchStates();
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: CommonAppBar(title: 'Add New School',backgroundColor: Colors.transparent,showText: true,),
      /// 🔹 APP BAR
      /// 🔹 BODY
      body: Column(
        children: [

          /// 🔹 SCROLLABLE CONTENT
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  stepProgress(
                    currentStep: currentStep,
                    totalSteps: 2,
                  ),

                  Text(
                    currentStep == 1 ? "Basic Information" : "Admin Details",
                    style: MyStyles.boldText(size: 16, color: AppTheme.black_Color),
                  ),

                  Text(
                    "Please provide the primary details for the new school entity.",
                    style: MyStyles.mediumText(size: 14, color: AppTheme.light_black_Color),
                  ),

                  currentStep == 1 ? schoolDetails() : adminDetails(),

                ].map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: e,
                )).toList(),
              ),
            ),
          ),

          /// 🔹 FIXED BOTTOM BUTTONS
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [

                if (currentStep == 2)
                  Expanded(
                    child: AppButton(
                      title: "Back",
                      isLoading: false,
                      color: AppTheme.btnColor,
                      onTap: () {
                        setState(() {
                          currentStep = 1;
                        });
                      },
                    ),
                  ),

                if (currentStep == 2)
                  const SizedBox(width: 10),

                Expanded(
                  child: AppButton(
                    title: "Next & Save",
                    isLoading: false,
                    color: AppTheme.btnColor,
                    onTap: () {
                      setState(() {
                        currentStep = 2;
                      });
                      navigateWithTransition(
                        context: context,
                        page: Dashboard(index: 0,),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 STEP HEADER (MATCH IMAGE)
  Widget stepProgress({required int currentStep, int totalSteps = 3}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// TOP TEXT
        Text(
          "STEP $currentStep OF $totalSteps",
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 8),

        /// PROGRESS BAR
        Row(
          children: List.generate(totalSteps, (index) {
            bool isActive = index < currentStep;

            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index != totalSteps - 1 ? 6 : 0),
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? Colors.blue : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: MyStyles.mediumText(size: 14, color: AppTheme.black_Color),
      ),
    );
  }

Widget schoolDetails(){
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        /// ADDRESS
        _label("School Name"),
        nameTextField(controller: schoolNameController,hintName: 'e.g. St. Sunrise Public School'),
        _label("Address"),
        nameTextField(controller: addressController,hintName: '109/43, Gaya Building, Yusuf Meharali Road, Mandvi"'),
        _label('Current Base Location'),
        GestureDetector(
          onTap: () async {
            final result = await navigateWithTransition(
              context: context,
              page: MapScreen(),
            );

            if (result != null) {
              setState(() {
                locationController.text = result["address"];
                Lat = result["lat"];
                Long = result["lng"];
              });
            }
          },
          child: AbsorbPointer(   // 🔥 Important
            child: nameTextField(
              controller: locationController,
              hintName: '109/43, Gaya Building, Yusuf Meharali Road, Mandvi',
              icon: Icons.location_searching,
              readOnly: true,   // 👈 अगर support करता है
            ),
          ),
        ),
        _label("URL"),
        nameTextField(controller: urlController,hintName: 'https://pub.dev/packages/easy_stepper/example'),
        _label('State'),
        Dropdown<States>(
          value: selectedState, // 👈 pass selected value here
          items: states,
          onChange: (States? value) {
            if (value == null) return;

            selectedState = value;
            fetchCities(value.id ?? 0);

            // reset city when state changes
            selectedCity = null;
          },
          hintText: selectedStateName,
          displayText: (int index, States value) {
            return value.name ?? '';
          },
        ),
        _label('City'),
        Dropdown<City>(
          value: selectedCity,
          items: cities,
          onChange: (City? value) {
            if (value == null) return;

            setState(() {
              selectedCity = value;
              cityId = value.id;   // optional but good practice
            });
          },
          hintText: selectedCityName,
          displayText: (int index, City value) {
            return value.name ?? '';
          },
        ),
        _label('Email Address'),
        nameTextField(controller: emailController,),
        _label('Phone Number'),
        phoneNumberTextField(controller: phoneController,),
        _label('Whatsapp Number'),
        phoneNumberTextField(controller: whatsappController,isRequired: false),
        _label('Website'),
        websiteTextField(controller: websiteController,isRequired: false),
        _label('School Logo'),
        LogoUploadView(
          imageUrl: firmLogoFile,
          onAddPhoto: () {
            // open image picker
            _showPicker(context,false);
          },
          onRemove: () {
            // remove image
          },
        ),
        _label('School Cover Photo'),
        /// IMAGE CARD
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: const DecorationImage(
              image: NetworkImage(
                "https://images.unsplash.com/photo-1596495577886-d920f1fb7238",
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.9),
                foregroundColor: Colors.black,
              ),
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text("Add School Cover Photo"),
            ),
          ),
        ),
      ].map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: e,
      ))
          .toList(),
    );
}
  Widget adminDetails(){
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _label("Admin Name"),
        nameTextField(controller: schoolNameController,hintName: 'e.g. Martin Goyal'),
        Text(
          "Admin Details",
          style: MyStyles.boldText(size: 16, color: AppTheme.black_Color),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8),
            ),
            border: Border.all(color: AppTheme.backBtnBgColor)
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [

                _label('Select Products'),
                Dropdown<States>(
                  value: selectedState, // 👈 pass selected value here
                  items: states,
                  onChange: (States? value) {
                    if (value == null) return;

                    selectedState = value;
                    fetchCities(value.id ?? 0);

                    // reset city when state changes
                    selectedCity = null;
                  },
                  hintText: selectedStateName,
                  displayText: (int index, States value) {
                    return value.name ?? '';
                  },
                ),
                _label("Price"),
                nameTextField(controller: schoolNameController,hintName: '₹45 per card'),
                _label("Approx. Qty*"),
                nameTextField(controller: schoolNameController,hintName: '50'),
              ],
            ),
          ),
        ),
        _label('Select ID Cards'),
        Dropdown<States>(
          value: selectedState, // 👈 pass selected value here
          items: states,
          onChange: (States? value) {
            if (value == null) return;

            selectedState = value;
            fetchCities(value.id ?? 0);

            // reset city when state changes
            selectedCity = null;
          },
          hintText: selectedStateName,
          displayText: (int index, States value) {
            return value.name ?? '';
          },
        ),
      ].map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: e,
      ))
          .toList(),
    );
  }
}