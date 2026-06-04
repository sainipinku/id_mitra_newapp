import 'dart:async';
import 'package:flutter/material.dart';
import 'package:idmitra/Widgets/svg_file.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/screens/dashboard/corporate/corporate_card.dart';
import 'package:idmitra/screens/dashboard/corporate/add_corporate_form.dart';
import 'package:idmitra/utils/navigation_utils.dart';

class CorporateList extends StatefulWidget {
  const CorporateList({super.key});

  @override
  State<CorporateList> createState() => _CorporateListState();
}

class _CorporateListState extends State<CorporateList> {
  TextEditingController searchController = TextEditingController();
  Timer? _debounce;
  int selectedStatusIndex = 0;
  final List<String> statusFilters = ["All", "Active", "Inactive"];

  final List<Map<String, String>> dummyCorporates = [
    {
      "name": "Reliance Industries",
      "address": "Mumbai, Maharashtra",
      "date": "12 May 2024",
      "status": "1",
      "logo":
          "https://upload.wikimedia.org/wikipedia/en/thumb/9/99/Reliance_Industries_Logo.svg/1200px-Reliance_Industries_Logo.svg.png",
    },
    {
      "name": "Tata Consultancy Services",
      "address": "Pune, Maharashtra",
      "date": "15 Jan 2024",
      "status": "1",
      "logo":
          "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b1/Tata_Consultancy_Services_Logo.svg/1200px-Tata_Consultancy_Services_Logo.svg.png",
    },
    {
      "name": "Infosys Limited",
      "address": "Bangalore, Karnataka",
      "date": "20 Mar 2024",
      "status": "0",
      "logo":
          "https://upload.wikimedia.org/wikipedia/commons/thumb/9/95/Infosys_logo.svg/1200px-Infosys_logo.svg.png",
    },
    {
      "name": "Wipro Limited",
      "address": "Hyderabad, Telangana",
      "date": "05 Feb 2024",
      "status": "1",
      "logo":
          "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a0/Wipro_Primary_Logo_Color_RGB.svg/1200px-Wipro_Primary_Logo_Color_RGB.svg.png",
    },
    {
      "name": "HCL Technologies",
      "address": "Noida, Uttar Pradesh",
      "date": "10 Apr 2024",
      "status": "0",
      "logo":
          "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0b/HCL_Technologies_logo.svg/1200px-HCL_Technologies_logo.svg.png",
    },
  ];

  List<Map<String, String>> filteredCorporates = [];

  @override
  void initState() {
    super.initState();
    filteredCorporates = List.from(dummyCorporates);
  }

  void _applyFilters() {
    setState(() {
      String query = searchController.text.toLowerCase();
      filteredCorporates = dummyCorporates.where((corp) {
        bool matchesSearch =
            corp['name']!.toLowerCase().contains(query) ||
            corp['address']!.toLowerCase().contains(query);

        bool matchesStatus = true;
        if (selectedStatusIndex == 1) {
          matchesStatus = corp['status'] == '1';
        } else if (selectedStatusIndex == 2) {
          matchesStatus = corp['status'] == '0';
        }

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          navigateWithTransition(
            context: context,
            page: const AddCorporateFormPage(),
          ).then((result) {
            if (result != null && result is Map<String, String>) {
              setState(() {
                dummyCorporates.add(result);
                _applyFilters();
              });
            }
          });
        },
        backgroundColor: AppTheme.btnColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _searchBar(),

            const SizedBox(height: 15),

            _statusFilterList(),

            const SizedBox(height: 15),

            Expanded(
              child: filteredCorporates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No Corporate found",
                            style: MyStyles.mediumText(
                              size: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filteredCorporates.length,
                      itemBuilder: (context, index) {
                        final corp = filteredCorporates[index];
                        return CorporateCard(
                          corporateData: corp,
                          onImageUpdate: (newPath) {
                            setState(() {
                              corp['logo'] = newPath;
                            });
                          },
                          onDelete: () {
                            setState(() {
                              dummyCorporates.removeWhere(
                                (c) => c['name'] == corp['name'],
                              );
                              _applyFilters();
                            });
                          },
                          onStatusToggle: () {
                            setState(() {
                              corp['status'] = corp['status'] == '1'
                                  ? '0'
                                  : '1';
                              _applyFilters();
                            });
                          },
                          onEdit: (data) {
                            navigateWithTransition(
                              context: context,
                              page: AddCorporateFormPage(editCorporate: data),
                            ).then((result) {
                              if (result != null &&
                                  result is Map<String, String>) {
                                setState(() {
                                  corp.addAll(result);
                                  _applyFilters();
                                });
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusFilterList() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: statusFilters.length,
        itemBuilder: (context, index) {
          final isSelected = selectedStatusIndex == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedStatusIndex = index;
                _applyFilters();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.btnColor
                    : AppTheme.appBackgroundColor,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.btnColor
                      : AppTheme.graySubTitleColor,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              alignment: Alignment.center,
              child: Text(
                statusFilters[index],
                style: MyStyles.mediumText(
                  size: 14,
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: searchController,
      style: MyStyles.regularText(size: 14, color: AppTheme.black_Color),
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppTheme.whiteColor,
        contentPadding: const EdgeInsets.all(12),
        hintText: 'Search by corporate name...',
        prefixIcon: const Icon(Icons.search),
        enabledBorder: appBorder(AppTheme.backBtnBgColor, 15),
        focusedBorder: appBorder(AppTheme.backBtnBgColor, 15),
        errorBorder: appBorder(AppTheme.errorMessageBackgroundColor, 15),
        focusedErrorBorder: appBorder(AppTheme.errorMessageBackgroundColor, 15),
        hintStyle: MyStyles.regularText(size: 14, color: AppTheme.black_Color),
      ),
    );
  }

  OutlineInputBorder appBorder(Color color, double radius) {
    return OutlineInputBorder(
      borderSide: BorderSide(color: color),
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
