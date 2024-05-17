class Validations {
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) return 'Name is Required.';
    final RegExp nameExp = new RegExp(r'^[A-za-zğüşöçİĞÜŞÖÇ ]+$');
    if (!nameExp.hasMatch(value))
      return 'Please enter only alphabetical characters.';
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter an Email Address.';
    final RegExp nameExp = new RegExp(
        r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,2"
        r"53}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-z"
        r"A-Z0-9])?)*$");
    if (!nameExp.hasMatch(value)) return 'Invalid email address';
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty || value.length < 6)
      return 'Please enter a valid password.';
    return null;
  }

  static String? validateId(String? value) {
    if (value == null || value.isEmpty) return 'ID is Required.';
    final RegExp idExp = RegExp(r'^[A-Za-z0-9]+$');
    if (!idExp.hasMatch(value)) return 'Please enter only alphanumeric characters.';
    return null;
  }
}
