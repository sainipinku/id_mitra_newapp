import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/Widgets/svg_file.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/providers/home/home_cubit.dart';
import 'package:idmitra/screens/SelectRolePage/SelectRolePage.dart';
import 'package:idmitra/screens/dashboard/StatCard.dart';
import 'package:idmitra/screens/dashboard/dashboard.dart';
import 'package:idmitra/utils/MyStyles.dart';
import 'package:idmitra/utils/navigation_utils.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 200),
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {

          /// 🔄 LOADING
          if (state.loading) {
            return const HomeShimmer();
          }

          /// ✅ SUCCESS
          else if (state.dashboard != null) {
            final data = state.dashboard!.data;

            return RefreshIndicator(
              onRefresh: () async {
                await context.read<HomeCubit>().loadHomeData();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// 🔹 STATS GRID
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [

                        StatCard(
                          title: "Total Schools",
                          value: data?.schools?.total?.toString() ?? "0",
                          icon: Icons.person,
                          color: Colors.blue,
                          button: (){
                            navigateWithTransition(
                              context: context,
                              page: Dashboard(index: 1,),
                            );
                          },
                        ),

                        StatCard(
                          title: "Active Schools",
                          value: data?.schools?.active?.toString() ?? "0",
                          icon: Icons.person_outline,
                          color: Colors.green,
                          button: (){},
                        ),

                        StatCard(
                          title: "Total Students",
                          value: data?.students?.total?.toString() ?? "0",
                          icon: Icons.school,
                          color: Colors.orange,
                          button: (){},
                        ),

                        StatCard(
                          title: "Total Employee",
                          value: data?.employees?.total?.toString() ?? "0",
                          icon: Icons.group,
                          color: Colors.purple,
                          button: (){},
                        ),

                        StatCard(
                          title: "Total Orders",
                          value: data?.orders?.total?.toString() ?? "0",
                          icon: Icons.receipt_long,
                          color: Colors.indigo,
                          button: (){},
                        ),

                        StatCard(
                          title: "Completed Orders",
                          value: data?.orders?.completeOrders?.toString() ?? "0",
                          icon: Icons.check_circle_outline,
                          color: Colors.teal,
                          button: (){},
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }

          /// ❌ ERROR / FALLBACK
          else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    state.error ?? "Something went wrong",
                    textAlign: TextAlign.center,
                    style: MyStyles.regularTxt(Colors.red, 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<HomeCubit>().loadHomeData(),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
