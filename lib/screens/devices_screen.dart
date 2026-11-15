import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../app/ui.dart';
import '../data/terra_store.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final parcels = context.watch<TerraStore>().parcels;
    final total = parcels.fold<int>(0, (sum, p) => sum + p.devices.length);
    final connected = parcels.fold<int>(
      0,
      (sum, p) => sum + p.devices.where((d) => d.connected).length,
    );
    return Column(
      children: [
        const PageIntro(
          eyebrow: 'Tecnología en tu campo',
          title: 'Dispositivos',
          subtitle: 'Sensores y equipos por parcela',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 25),
            children: [
              StaggerItem(
                index: 0,
                child: SurfaceCard(
                  color: context.colors.softBlue,
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.hub_outlined,
                          color: context.colors.blue,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$total dispositivos',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: context.colors.ink,
                              ),
                            ),
                            Text(
                              '$connected conectados ahora',
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 23),
              Text(
                'Conectados a tus parcelas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 13),
              if (total == 0)
                const SurfaceCard(
                  child: Text('No hay dispositivos asociados.'),
                ),
              for (var i = 0; i < parcels.length; i++)
                if (parcels[i].devices.isNotEmpty) ...[
                  StaggerItem(
                    index: i + 1,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.grid_view_rounded,
                                  size: 17,
                                  color: context.colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    parcels[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: context.colors.ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${parcels[i].devices.length} equipos',
                                  style: TextStyle(
                                    color: context.colors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            for (final device in parcels[i].devices) ...[
                              Divider(height: 18, color: context.colors.border),
                              Row(
                                children: [
                                  Container(
                                    width: 39,
                                    height: 39,
                                    decoration: BoxDecoration(
                                      color: context.colors.canvas,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _icon(device.kind),
                                      color: context.colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          device.name,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          device.kind,
                                          style: TextStyle(
                                            color: context.colors.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _StatusDot(active: device.connected),
                                  const SizedBox(width: 5),
                                  Text(
                                    device.connected
                                        ? '${device.battery}%'
                                        : 'Sin conexión',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: device.connected
                                          ? context.colors.green
                                          : context.colors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }

  IconData _icon(String kind) => switch (kind) {
    'Clima' => Icons.cloud_outlined,
    'Riego' => Icons.water_drop_outlined,
    _ => Icons.sensors_outlined,
  };
}

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.active});
  final bool active;
  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, _) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.active ? context.colors.green : context.colors.muted,
        boxShadow: widget.active
            ? [
                BoxShadow(
                  color: context.colors.green.withValues(
                    alpha: .15 + controller.value * .3,
                  ),
                  blurRadius: 4 + controller.value * 5,
                ),
              ]
            : [],
      ),
    ),
  );
}
