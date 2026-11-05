/// Resource UUIDs must never be used as a public account identifier.
String? providerPublicId(Object? value) =>
    value is String && RegExp(r'^[1-9][0-9]{5,63}$').stringMatch(value) == value
    ? value
    : null;
