
Widget buildResps() {
  if (resps.isEmpty) {
    return const Center(
      child: Text('कोई Response नहीं'),
    );
  }

  return ListView.builder(
    itemCount: resps.length,
    itemBuilder: (context, index) {
      final r = resps[resps.length - 1 - index];

      return Card(
        margin: const EdgeInsets.all(8),
        child: ListTile(
          title: Text(r.formTitle),
          subtitle: Text(
            '${r.date}\n'
            'GPS: ${r.gps}\n'
            '${r.address}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          leading: r.photo.isNotEmpty
              ? Image.file(
                  File(r.photo),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image);
                  },
                )
              : const Icon(Icons.location_on),
        ),
      );
    },
  );
}
Future<String> getLocationFull() async {
  try {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return 'GPS Off है';
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return 'GPS Permission नहीं मिली';
    }

    if (permission == LocationPermission.deniedForever) {
      return 'GPS Permission Settings से चालू करें';
    }

    final position = await Geolocator.getCurrentPosition();

    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    final address = placemarks.isNotEmpty
        ? '${placemarks.first.street ?? ''}, '
          '${placemarks.first.locality ?? ''}'
        : '';

    return '${position.latitude.toStringAsFixed(6)}, '
        '${position.longitude.toStringAsFixed(6)}|$address';
  } catch (e) {
    return 'GPS Error';
  }
}
