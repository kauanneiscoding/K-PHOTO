import 'package:flutter/material.dart';
import 'data_storage_service.dart';

class BinderCard extends StatefulWidget {
  final DataStorageService dataStorageService;
  final String binderId;

  const BinderCard({
    Key? key,
    required this.dataStorageService,
    required this.binderId,
  }) : super(key: key);

  @override
  _BinderCardState createState() => _BinderCardState();
}

class _BinderCardState extends State<BinderCard> {
  bool isOpen = false;
  static const double binderSpineWidth = 30.0;
  static const double binderCoverWidth = 180.0;
  static const double fixedHeight = 240.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isOpen = !isOpen;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        width: isOpen ? binderCoverWidth : binderSpineWidth,
        height: fixedHeight,
        decoration: BoxDecoration(
          color: Colors.pink[100],
          borderRadius: BorderRadius.circular(isOpen ? 10 : 5),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Center(
          child: RotatedBox(
            quarterTurns: isOpen ? 0 : 1,
            child: Text(
              'Álbum ${widget.binderId.split('_').last}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
