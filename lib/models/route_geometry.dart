/// Validates provider geometry instead of fabricating a straight-line route.
List<List<double>> decodeRoutePolyline(String encoded) {
  final points = <List<double>>[];
  var index = 0, lat = 0, lng = 0;
  int coordinate() {
    var result = 0, shift = 0;
    int byte;
    do {
      if (index >= encoded.length || shift > 30) {
        throw const FormatException('Invalid route geometry');
      }
      byte = encoded.codeUnitAt(index++) - 63;
      if (byte < 0 || byte > 63) {
        throw const FormatException('Invalid route geometry');
      }
      result |= (byte & 31) << shift;
      shift += 5;
    } while (byte >= 32);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    lat += coordinate();
    lng += coordinate();
    final a = lat / 1e5, b = lng / 1e5;
    if (a.abs() > 90 || b.abs() > 180) {
      throw const FormatException('Route outside geographic bounds');
    }
    points.add([a, b]);
    if (points.length > 100000) throw const FormatException('Route too large');
  }
  if (points.length < 2) {
    throw const FormatException('No road geometry returned');
  }
  return points;
}
