class Student {
  const Student({required this.nisn});
  final String nisn;
}

class Agenda {
  const Agenda(this.title, this.time, this.place, this.description);
  final String title, time, place, description;
}
