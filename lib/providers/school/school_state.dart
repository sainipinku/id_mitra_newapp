import 'package:idmitra/models/schools/SchoolListModel.dart'; 
 
 class SchoolState { 
   final bool loading; 
   final bool isSyncing; 
   final bool isPaginationLoading; 
   final List<SchoolDetailsModel> students; 
   final int page; 
   final bool hasMore; 
   final String? error; 
   final Map<int, String> imageShapeMap; // schoolId -> imageShape
 
   SchoolState({ 
     this.loading = false, 
     this.isSyncing = false, 
     this.isPaginationLoading = false, 
     this.students = const [], 
     this.page = 1, 
     this.hasMore = true, 
     this.error, 
     this.imageShapeMap = const {},
   }); 
 
   SchoolState copyWith({ 
     bool? loading, 
     bool? isSyncing, 
     bool? isPaginationLoading, 
     List<SchoolDetailsModel>? students, 
     int? page, 
     bool? hasMore, 
     String? error, 
     Map<int, String>? imageShapeMap,
   }) { 
     return SchoolState( 
       loading: loading ?? this.loading, 
       isSyncing: isSyncing ?? this.isSyncing, 
       isPaginationLoading: isPaginationLoading ?? this.isPaginationLoading, 
       students: students ?? this.students, 
       page: page ?? this.page, 
       hasMore: hasMore ?? this.hasMore, 
       error: error ?? this.error, 
       imageShapeMap: imageShapeMap ?? this.imageShapeMap,
     ); 
   } 
 } 
