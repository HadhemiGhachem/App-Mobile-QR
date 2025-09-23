import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'models/student.dart';

void main() {
  runApp(MyApp());
}

// Modèle pour chaque QR code
class QRCodeItem {
  final String hash;
  final String qrcode;
  final String studentId;
  final String nom;
  final String prenom;
  final String cin;
  final String exam;
  final String examDate;
  final String NINSCRI; // 🔹 ajouter


  QRCodeItem({
    required this.hash,
    required this.qrcode,
    required this.studentId,
    required this.nom,
    required this.prenom,
    required this.cin,
    required this.exam,
    required this.examDate,
    required this.NINSCRI, // 🔹 ajouter

  });

factory QRCodeItem.fromJson(Map<String, dynamic> json) {
  return QRCodeItem(
    hash: json['hash']?.toString() ?? '',
    qrcode: json['qrcode']?.toString() ?? '',
    studentId: json['student_id']?.toString() ?? '',
    nom: json['nom']?.toString() ?? '',
    prenom: json['prenom']?.toString() ?? '',
    cin: json['cin']?.toString() ?? '',
    exam: json['exam']?.toString() ?? '',
    examDate: json['exam_date']?.toString() ?? '',
    NINSCRI: json['numero_inscri']?.toString() ?? '',

  );
}

}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ExcelDisplayScreen(),
    );
  }
}

class ExcelDisplayScreen extends StatefulWidget {
  @override
  _ExcelDisplayScreenState createState() => _ExcelDisplayScreenState();
}

class _ExcelDisplayScreenState extends State<ExcelDisplayScreen> {
  List<List<dynamic>> _excelData = [];
  List<QRCodeItem> _qrCodes = [];
  String _status = '';
  bool _isLoading = false;
  File? _selectedFile;

  Future<void> _uploadFile() async {
    setState(() {
      _isLoading = true;
      _status = 'Sélection du fichier...';
      _qrCodes = [];
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null) {
        setState(() {
          _status = 'Aucun fichier sélectionné';
          _isLoading = false;
        });
        return;
      }

      File file = File(result.files.single.path!);
      _selectedFile = file;
      setState(() => _status = 'Upload en cours...');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8000/api/upload-excel'),
      );
      request.files.add(await http.MultipartFile.fromPath('excel_file', file.path));
      var response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      if (response.statusCode == 200 && jsonData['data'] != null) {
        setState(() {
          _excelData = List<List<dynamic>>.from(
              jsonData['data'].map((row) => List<dynamic>.from(row)));
          _status = 'Données chargées avec succès !';
          _isLoading = false;
        });
      } else {
        setState(() {
          _status = jsonData['error'] ??
              'Erreur lors de l\'upload (code ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Erreur : $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateQRCode() async {
    if (_selectedFile == null) {
      setState(() => _status = 'Aucun fichier sélectionné pour générer les QR codes');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Génération des QR codes en cours...';
      _qrCodes = [];
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8000/api/generate-qrcodes'),
      );
      request.files.add(await http.MultipartFile.fromPath('excel_file', _selectedFile!.path));
      var response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      if (response.statusCode == 200 && jsonData['qrcodes'] != null) {
        setState(() {
          _qrCodes = (jsonData['qrcodes'] as List)
              .map((e) => QRCodeItem.fromJson(e as Map<String, dynamic>))
              .toList();
          _status = 'QR codes générés avec succès !';
          _isLoading = false;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QRCodesScreen(qrCodes: _qrCodes),
          ),
        );
      } else {
        setState(() {
          _status = jsonData['error'] ??
              'Erreur lors de la génération (code ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Erreur : $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Afficher Excel'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _isLoading ? null : _uploadFile,
                      child: Text(_isLoading ? 'Chargement...' : 'Sélectionner et Uploader Excel'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _status.contains('Erreur') ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading) Expanded(child: Center(child: CircularProgressIndicator())),
            if (_excelData.isNotEmpty && !_isLoading)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: _excelData[0]
                        .map((header) => DataColumn(label: Text(header.toString())))
                        .toList(),
                    rows: _excelData.skip(1).map((row) {
                      return DataRow(
                        cells: row.map((cell) => DataCell(Text(cell.toString()))).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ),
            if (_excelData.isNotEmpty && !_isLoading)
              ElevatedButton(
                onPressed: _generateQRCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Générer QR Codes'),
              ),
          ],
        ),
      ),
    );
  }
}

class QRCodesScreen extends StatefulWidget {
  final List<QRCodeItem> qrCodes;
  const QRCodesScreen({required this.qrCodes, super.key});

  @override
  _QRCodesScreenState createState() => _QRCodesScreenState();
}

class _QRCodesScreenState extends State<QRCodesScreen> {
  bool _isGeneratingPDF = false;

  Future<void> _generatePDF() async {
    final validQRCodes = widget.qrCodes.map((qr) => {
      'student_id': qr.studentId,
      'nom': qr.nom,
      'prenom': qr.prenom,
      'cin': qr.cin,
      'numero_inscri': qr.NINSCRI,
      'exam': qr.exam,
      'exam_date': qr.examDate,
      'qrcode': qr.qrcode,
    }).toList();


    if (validQRCodes.isEmpty) return;

    setState(() => _isGeneratingPDF = true);

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/generate-pdf'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'qrcodes': validQRCodes}),
      );

      if (response.statusCode == 200 &&
          response.headers['content-type']?.contains('application/pdf') == true) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/qrcodes.pdf');
        await file.writeAsBytes(response.bodyBytes);
        await OpenFile.open(file.path);
      } else {
        debugPrint('Erreur génération PDF: ${response.body}');
      }
    } catch (e) {
      debugPrint('Erreur génération PDF: $e');
    } finally {
      setState(() => _isGeneratingPDF = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Codes Générés'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.qrCodes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "${widget.qrCodes[0].exam} - ${widget.qrCodes[0].examDate}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            Expanded(
              child: widget.qrCodes.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun QR code à afficher',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : GridView.builder(
                      itemCount: widget.qrCodes.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.9,
                      ),
                      itemBuilder: (context, index) {
                        final qr = widget.qrCodes[index];
                        Uint8List bytes;
                        try {
                          bytes = base64Decode(qr.qrcode);
                        } catch (_) {
                          return const Card(
                            child: Center(
                              child: Text('QR Code invalide',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          );
                        }

                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${qr.studentId} - ${qr.nom} ${qr.prenom}",
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text("CIN: ${qr.cin}",
                                    style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 8),
                                Image.memory(bytes, width: 100, height: 100),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (widget.qrCodes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  onPressed: _isGeneratingPDF ? null : _generatePDF,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: _isGeneratingPDF
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Text('Générer en PDF'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
