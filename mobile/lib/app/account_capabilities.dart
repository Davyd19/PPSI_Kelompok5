import '../network/auth_api.dart';

enum TeacherFeature {
  homeroomCases,
  caseManagement,
  counselingPlans,
  extracurricular,
}

/// UI capabilities reflect the authenticated profile; API permission checks remain authoritative.
class AccountCapabilities {
  AccountCapabilities(this.profile);
  final AccountProfile profile;
  bool get isTeacher =>
      profile.primaryRole == 'GURU' ||
      profile.primaryRole == 'GURU_BK' ||
      (profile.primaryRole == null && profile.roles.contains('GURU'));
  bool get isBk => profile.roles.contains('GURU_BK');
  bool get isHomeroom => profile.roles.contains('WALI_KELAS');
  bool get isCoach => profile.roles.contains('PEMBINA_EKSTRAKURIKULER');
  bool permits(TeacherFeature feature) =>
      isTeacher &&
      switch (feature) {
        TeacherFeature.caseManagement || TeacherFeature.counselingPlans => isBk,
        TeacherFeature.homeroomCases => isHomeroom,
        TeacherFeature.extracurricular => isCoach,
      };
}
