import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/svg_file.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/providers/school/school_cubit.dart';
import 'package:idmitra/providers/school/school_state.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/screens/partner/dashboard/users/schools_details_widgets.dart';

import 'package:idmitra/utils/MyStyles.dart';

class Schools extends StatefulWidget {
  const Schools({super.key});

  @override
  State<Schools> createState() => _SchoolsState();
}

class _SchoolsState extends State<Schools>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> filters = ["All", "Schools", "Colleges", "Corporate"];

  Timer? _debounce;
  int selectedIndex = 0;

  bool get _isSearching => searchController.text.trim().isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    final cubit = context.read<SchoolCubit>();

    /// Load only first time
    if (cubit.state.students.isEmpty) {
      cubit.loadSchoolsData();
    }

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<SchoolCubit>().fetchStudents(
        isLoadMore: true,
        search: searchController.text.trim(),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// SEARCH BAR
            _searchBar(),

            const SizedBox(height: 15),

            _filterList(),

            const SizedBox(height: 15),

            BlocBuilder<SchoolCubit, SchoolState>(
              builder: (context, state) {
                /// 🔄 LOADING (first load — no data yet)
                if (state.loading && state.students.isEmpty) {
                  return const SchoolListShimmer();
                }

                /// ❌ ERROR (no data to show)
                if (state.error != null && state.students.isEmpty) {
                  return Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),

                          const SizedBox(height: 12),

                          Text(
                            state.error!,
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 16),

                          ElevatedButton(
                            onPressed: () {
                              context
                                  .read<SchoolCubit>()
                                  .loadSchoolsData();
                            },
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                /// ✅ LIST
                return Expanded(
                  child: state.students.isEmpty
                      ? Center(
                    child: Image.asset(
                      "assets/images/no_data.png",
                      height: 200,
                    ),
                  )
                      : RefreshIndicator(
                    onRefresh: () async {
                      if (_isSearching) {
                        await context
                            .read<SchoolCubit>()
                            .fetchStudents(
                          search:
                          searchController.text.trim(),
                        );
                      } else {
                        await context
                            .read<SchoolCubit>()
                            .loadSchoolsData();
                      }
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      physics:
                      const AlwaysScrollableScrollPhysics(),
                      itemCount: state.students.length +
                          (state.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < state.students.length) {
                          final item = state.students[index];

                          return SchoolsDetailsWidgets(
                            schoolDetailsModel: item,
                          );
                        } else {
                          /// Pagination loader
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child:
                              CircularProgressIndicator(),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  Widget _filterList() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final isSelected = selectedIndex == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedIndex = index;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding:
              const EdgeInsets.symmetric(horizontal: 16),
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
                filters[index],
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.black,
                  fontWeight: FontWeight.w500,
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
      style: MyStyles.regularTxt(
        AppTheme.black_Color,
        14,
      ),
      onChanged: (value) {
        if (_debounce?.isActive ?? false) {
          _debounce!.cancel();
        }

        _debounce = Timer(
          const Duration(milliseconds: 500),
              () {
            final query = value.trim();

            if (query.isEmpty) {
              /// Reload local DB data
              context
                  .read<SchoolCubit>()
                  .loadSchoolsData();
            } else {
              /// API Search
              context
                  .read<SchoolCubit>()
                  .fetchStudents(search: query);
            }
          },
        );
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: AppTheme.whiteColor,
        contentPadding: const EdgeInsets.all(12),
        hintText: 'Search by name...',
        prefixIcon: const Icon(Icons.search),
        enabledBorder:
        _appBorder(AppTheme.backBtnBgColor, 15),
        focusedBorder:
        _appBorder(AppTheme.backBtnBgColor, 15),
        errorBorder: _appBorder(
          AppTheme.errorMessageBackgroundColor,
          15,
        ),
        focusedErrorBorder: _appBorder(
          AppTheme.errorMessageBackgroundColor,
          15,
        ),
        hintStyle: MyStyles.regularTxt(
          AppTheme.black_Color,
          14,
        ),
      ),
    );
  }

  OutlineInputBorder _appBorder(
      Color color,
      double radius,
      ) {
    return OutlineInputBorder(
      borderSide: BorderSide(color: color),
      borderRadius: BorderRadius.circular(radius),
    );
  }
}