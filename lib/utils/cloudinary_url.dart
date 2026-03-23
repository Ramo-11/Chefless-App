/// Transforms a Cloudinary URL to request a resized image on-the-fly.
///
/// Cloudinary supports URL-based transformations. This inserts
/// `w_{width},h_{height},c_fill,q_auto,f_auto` into the URL path,
/// so the CDN delivers an optimally sized image instead of the full-res original.
///
/// If the URL is not a Cloudinary URL, it is returned unchanged.
String cloudinaryUrl(String url, {required int width, int? height}) {
  if (!url.contains('res.cloudinary.com')) return url;

  // Cloudinary URL format:
  // https://res.cloudinary.com/{cloud}/image/upload/v{version}/{path}
  // Insert transformations after /upload/
  final uploadIndex = url.indexOf('/upload/');
  if (uploadIndex == -1) return url;

  final insertAt = uploadIndex + '/upload/'.length;
  final transform = height != null
      ? 'w_$width,h_$height,c_fill,q_auto,f_auto/'
      : 'w_$width,c_fill,q_auto,f_auto/';

  return '${url.substring(0, insertAt)}$transform${url.substring(insertAt)}';
}
