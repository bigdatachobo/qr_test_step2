import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'database.dart';
import 'empty_space.dart';
import 'home_page.dart';

class QRScannerPage extends StatefulWidget {
  final bool isInbound;
  final String? selectedLocationKey;

  QRScannerPage({
    required this.isInbound,
    this.selectedLocationKey,
  });

  @override
  _QRScannerPageState createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  QRViewController? _controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Timer? _timer;
  bool _isQRCodeDetected = false;

  final RegExp pattern = RegExp(r'^[A-Z]\d{5}_\d{10}$');

  @override
  void dispose() {
    _controller?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      _controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      // QR 코드가 스캔 되고 이전에 표시된 경고 대화 상자가 없는 경우
      if (!_isQRCodeDetected && scanData.code != null) {
        // QR 코드가 정규식 패턴과 일치 하는 경우
        if (pattern.hasMatch(scanData.code!)) {
          _isQRCodeDetected = true;
          _controller?.pauseCamera();
          processQRCode(context, scanData.code!, widget.isInbound);
        } else {
          // 이전에 표시된 경고 대화 상자가 없는 경우
          if (!_isQRCodeDetected) {
            // 경고 대화 상자를 표시 중임을 나타내기 위해 _isQRCodeDetected를 true로 설정
            _isQRCodeDetected = true;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Invalid code format'),
                content: const Text('The code must be \nin the format of \n"B00000_0000000000".'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _controller?.resumeCamera();
                      // 경고 대화상자를 닫은 후, _isQRCodeDetected를 false로 설정하여 다음 경고 대화상자를 표시할 수 있게 함
                      _isQRCodeDetected = false;
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
    });
  }


  Future<void> processQRCode(BuildContext context, String code, bool isInbound) async {
    if (isInbound) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmptySpacePage(),
        ),
      ).then((selectedLocationKey) async {
        if (selectedLocationKey != null) {
          await addOrUpdateItem(code, selectedLocationKey);
          // ignore: use_build_context_synchronously
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Success'),
              content: const Text('입고 완료'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        // ignore: use_build_context_synchronously
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(),
          ),
              (route) => false,
        );
      });
    } else {
      // Set item as "출하" in the database
      await setItemAsOutbound(code);
      // ignore: use_build_context_synchronously
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: const Text('출고 완료'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      // ignore: use_build_context_synchronously
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(),
        ),
            (route) => false,
      );
    }
    setState(() {
      _isQRCodeDetected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner'),
      ),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
          ),
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isQRCodeDetected ? Colors.green : Colors.white,
                  width: 5.0,
                ),
              ),
              child: _isQRCodeDetected
                  ? const SpinKitRing(
                color: Colors.green,
                lineWidth: 4,
                size: 100,
              )
                  : null,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _controller?.toggleFlash();
        },
        child: const Icon(Icons.flash_on),
      ),
    );
  }
}
