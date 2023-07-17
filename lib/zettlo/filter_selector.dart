import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;

import 'package:google_fonts/google_fonts.dart';

class FilterSelector extends StatefulWidget {
  final String filterImage;
  final List<Color> filters;
  final Color? selectedFilter;
  final Function(Color selectedColor) onFilterChanged;
  final GestureTapCallback onTap;

  const FilterSelector({
    Key? key,
    required this.filters,
    required this.onFilterChanged,
    required this.onTap,
    this.selectedFilter,
    required this.filterImage,
  }) : super(key: key);

  @override
  State<FilterSelector> createState() => _FilterSelectorState();
}

class _FilterSelectorState extends State<FilterSelector> {
  static const filtersPerScreen = 5;
  static const _viewportFractionPerItem = 1.0 / filtersPerScreen;

  late final PageController _controller;
  late int _page;
  int get filterCount => widget.filters.length;
  Color itemColor(int index) => widget.filters[index % filterCount];
  final padding = const EdgeInsets.symmetric(vertical: 24.0);

  @override
  void initState() {
    super.initState();
    final s = widget.filters.indexWhere((element) => element == widget.selectedFilter);
    if (widget.selectedFilter != null) {
      _page = s;
    } else {
      _page = 0;
    }

    _controller = PageController(
      initialPage: _page,
      viewportFraction: _viewportFractionPerItem,
    );
    _controller.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = (_controller.page ?? 0).round();
    if (page != _page) {
      _page = page;
      widget.onFilterChanged(widget.filters[page]);
    }
  }

  void _onFilterTapped(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.ease,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollable(
      controller: _controller,
      axisDirection: AxisDirection.right,
      physics: const PageScrollPhysics(),
      viewportBuilder: (context, offset) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth * _viewportFractionPerItem;
            offset
              ..applyViewportDimension(constraints.maxWidth)
              ..applyContentDimensions(
                0.0,
                size * (filterCount - 1),
              );
            return Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  height: 250,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                        ],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
                Positioned(
                  top: 24.0,
                  left: 24.0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Filters",
                        style: GoogleFonts.poppins(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "Apply filters to beautify your engagement",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: size,
                  margin: padding,
                  child: Flow(
                    delegate: CarouselFlowDelegate(
                      viewportOffset: offset,
                      filtersPerScreen: filtersPerScreen,
                    ),
                    children: [
                      for (int i = 0; i < filterCount; i++)
                        FilterItem(
                          filterImage: widget.filterImage,
                          onVideoFilter: true,
                          onFilterSelected: () => _onFilterTapped(i),
                          color: itemColor(i),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  child: IgnorePointer(
                    child: Padding(
                      padding: padding,
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(
                                width: 6.0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              ],
            );
          },
        );
      },
    );
  }
}

class CarouselFlowDelegate extends FlowDelegate {
  CarouselFlowDelegate({
    required this.viewportOffset,
    required this.filtersPerScreen,
  }) : super(repaint: viewportOffset);

  final ViewportOffset viewportOffset;
  final int filtersPerScreen;

  @override
  void paintChildren(FlowPaintingContext context) {
    final count = context.childCount;
    final size = context.size.width;
    final itemExtent = size / filtersPerScreen;
    final active = viewportOffset.pixels / itemExtent;
    final int min = math.max(0, active.floor() - 3);
    final int max = math.min(count - 1, active.ceil() + 3);
    for (var index = min; index <= max; index++) {
      final itemXFromCenter = itemExtent * index - viewportOffset.pixels;
      final percentFromCenter = 1.0 - (itemXFromCenter / (size / 2)).abs();
      final itemScale = 0.5 + (percentFromCenter * 0.5);
      final opacity = 0.25 + (percentFromCenter * 0.75);

      final itemTransform = Matrix4.identity()
        ..translate((size - itemExtent) / 2)
        ..translate(itemXFromCenter)
        ..translate(itemExtent / 2, itemExtent / 2)
        ..multiply(Matrix4.diagonal3Values(itemScale, itemScale, 1.0))
        ..translate(-itemExtent / 2, -itemExtent / 2);

      context.paintChild(
        index,
        transform: itemTransform,
        opacity: opacity,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CarouselFlowDelegate oldDelegate) {
    return oldDelegate.viewportOffset != viewportOffset;
  }
}

@immutable
class FilterItem extends StatelessWidget {
  final String filterImage;
  const FilterItem({
    Key? key,
    required this.color,
    required this.onVideoFilter,
    this.onFilterSelected,
    required this.filterImage,
  }) : super(key: key);

  final Color color;
  final bool onVideoFilter;
  final VoidCallback? onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onFilterSelected,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: ClipOval(
          child: Image.asset(
            filterImage,
            color: color.withOpacity(0.5),
            fit: BoxFit.cover,
            colorBlendMode: BlendMode.hardLight,
          ),
        ),
      ),
    );
  }
}
