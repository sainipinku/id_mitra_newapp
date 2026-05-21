part of 'home_cubit.dart'; 
 
 class HomeState { 
   final bool loading; 
   final PartnerDashboardModel? dashboard; 
   final UserDetailsModel? user; 
   final String? error; 
 
   HomeState({ 
     this.loading = false, 
     this.dashboard, 
     this.user, 
     this.error, 
   }); 
 
   HomeState copyWith({ 
     bool? loading, 
     PartnerDashboardModel? dashboard, 
     UserDetailsModel? user, 
     String? error, 
   }) { 
     return HomeState( 
       loading: loading ?? this.loading, 
       dashboard: dashboard ?? this.dashboard, 
       user: user ?? this.user, 
       error: error ?? this.error, 
     ); 
   } 
 } 
