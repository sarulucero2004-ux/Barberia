import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/barber.dart';

class AboutUsSection extends StatelessWidget {
  final List<Barber> barbers;

  const AboutUsSection({
    Key? key,
    required this.barbers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isMobile = width < 768;

    return Container(
      color: const Color(0xFF121212),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : 64.0,
        vertical: 80.0,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'QUIÉNES SOMOS',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  letterSpacing: 3,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'LOS AMIGOS',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 80,
                height: 3,
                color: const Color(0xFFD4AF37),
              ),
              const SizedBox(height: 24),
              const Text(
                'EN NUESTRO ESPACIO NOS GUSTA CONECTARNOS CON NUESTROS CLIENTES, NO ES SOLO UN ESPACIO PARA TRABAJO, SINO PARA HACER AMISTADES YA SEAN NIÑOS, ADOLESCENTES O ADULTOS. ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              // Grid/Column of Barbers
              isMobile
                  ? Column(
                      children: barbers.map((barber) => _buildBarberCard(barber, true)).toList(),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: barbers.map((barber) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: _buildBarberCard(barber, false),
                            ),
                          )).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarberCard(Barber barber, bool isMobile) {
    final galleryDirectory = _galleryDirectoryFor(barber);
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 32.0 : 0.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagen del Barbero
          AspectRatio(
            aspectRatio: 4 / 3,
            child: barber.imageUrl == null
                ? _barberPlaceholder()
                : Image.asset(
                    barber.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _barberPlaceholder(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  barber.name.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  barber.specialty,
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Color(0xFFD4AF37), size: 18),
                    const SizedBox(width: 4),
                    const SizedBox(width: 4),
                    const Text(
                      '/ 5.0 (Reseñas)',
                      style: TextStyle(color: Colors.white30, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (galleryDirectory != null)
            _BarberGallery(
              directory: galleryDirectory,
              barberName: barber.name,
            ),
        ],
      ),
    );
  }

  String? _galleryDirectoryFor(Barber barber) {
    switch (barber.imageAssetPath) {
      case 'assets/images/barber_ezequiel.png':
        return 'assets/images/galeria/ezequiel';
      case 'assets/images/barber_isaias.png':
        return 'assets/images/galeria/isaias';
      default:
        return null;
    }
  }

  Widget _barberPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.person, size: 64, color: Colors.white54),
    );
  }
}

class _BarberGallery extends StatefulWidget {
  final String directory;
  final String barberName;

  const _BarberGallery({
    required this.directory,
    required this.barberName,
  });

  @override
  State<_BarberGallery> createState() => _BarberGalleryState();
}

class _BarberGalleryState extends State<_BarberGallery> {
  late final Future<List<String>> _images = _loadImages();

  Future<List<String>> _loadImages() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final prefix = '${widget.directory}/';
    final imageExtensions = {'png', 'jpg', 'jpeg', 'webp'};

    return manifest.listAssets().where((asset) {
      if (!asset.startsWith(prefix)) return false;
      final extension = asset.split('.').last.toLowerCase();
      return imageExtensions.contains(extension);
    }).toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: FutureBuilder<List<String>>(
        future: _images,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text(
              'No se pudieron cargar las fotografías.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFD4AF37),
                  ),
                ),
              ),
            );
          }

          final images = snapshot.data!;
          if (images.isEmpty) {
            return Text(
              'Próximamente habrá trabajos de ${widget.barberName}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            );
          }

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final imagePath = images[index];
              return Semantics(
                button: true,
                label: 'Ampliar fotografía de ${widget.barberName}',
                child: GestureDetector(
                  onTap: () => _showImage(context, imagePath),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.white10,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showImage(BuildContext context, String imagePath) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  child: Image.asset(imagePath, fit: BoxFit.contain),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar fotografía',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}
