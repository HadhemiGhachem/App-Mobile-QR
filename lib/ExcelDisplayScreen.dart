import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

// Modèle pour chaque QR code et étudiant
class QRCodeItem {
  final String hash;
  final String qrcode;
  final String studentId;
  final String firstName;
  final String lastName;
  final String cin;
  final String exam;
  final String examDate;
  final String NINSCRI;
  double? note; // Rendu non-final pour pouvoir être mis à jour après l'import

  QRCodeItem({
    required this.hash,
    required this.qrcode,
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.cin,
    required this.exam,
    required this.examDate,
    required this.NINSCRI,
    this.note,
  });

  factory QRCodeItem.fromJson(Map<String, dynamic> json) {
    return QRCodeItem(
      hash: json['hash']?.toString() ?? '',
      qrcode: json['qrcode']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      firstName: json['prenom']?.toString() ?? '',
      lastName: json['nom']?.toString() ?? '',
      cin: json['cin']?.toString() ?? '',
      exam: json['exam']?.toString() ?? '',
      examDate: json['exam_date']?.toString() ?? '',
      NINSCRI: json['numero_inscri']?.toString() ?? '',
      note: (json['note'] as num?)?.toDouble(), // Conversion de la note
    );
  }

  // Méthode nécessaire pour envoyer les données complètes au générateur de PDF Laravel
  Map<String, dynamic> toJson() {
    return {
      'numero_inscri': NINSCRI,
      'cin': cin,
      'nom': lastName,
      'prenom': firstName,
      'exam': exam,
      'exam_date': examDate,
      'note': note, 
    };
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestion des Examens',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // ⚠️ IMPORTANT : Suppression de la définition de route nommée '/notesDisplay'
      // car elle ne peut pas fournir l'argument 'allStudents'.
      // La navigation se fait via Navigator.push dans l'écran principal.
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
  List<QRCodeItem> _qrCodes = []; // Liste des étudiants après génération des QR codes
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
          _status = 'QR codes générés avec succès ! (${_qrCodes.length} étudiants)';
          _isLoading = false;
        });

        // Naviguer vers l'écran des QR codes
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
    // Vérifie si les QR codes ont été générés avant de pouvoir passer à l'écran des notes
    final bool isReadyForNotes = _qrCodes.isNotEmpty && !_isLoading; 

    return Scaffold(
      appBar: AppBar(title: Text('Gestion des Examens'), centerTitle: true),
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
                      child: Text(_isLoading ? 'Chargement...' : '1. Importer la liste des étudiants'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _excelData.isNotEmpty && !_isLoading ? _generateQRCode : null,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('2. Générer et afficher les QR Codes'),
                    ),
                    const SizedBox(height: 8),
                    // Navigation correcte utilisant Navigator.push
                    ElevatedButton(
                      onPressed: isReadyForNotes ? () {
                        Navigator.push(
                          context,
                          // Passe la liste _qrCodes comme argument 'allStudents'
                          MaterialPageRoute(builder: (context) => NotesScreen(allStudents: _qrCodes)),
                        );
                      } : null,
                      style: ElevatedButton.styleFrom(backgroundColor: isReadyForNotes ? Colors.orange : Colors.grey),
                      child: const Text('3. Importer les notes des examens'),
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
      'nom': qr.firstName,
      'prenom': qr.lastName,
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
        
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF des QR Codes généré avec succès !')));
            
        await OpenFile.open(file.path);
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la génération du PDF des QR Codes: ${response.statusCode}')));
        debugPrint('Erreur génération PDF: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de connexion pour le PDF: $e')));
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
                                  "${qr.studentId} - ${qr.firstName} ${qr.lastName}",
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
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingPDF ? null : _generatePDF,
                  icon: _isGeneratingPDF 
                     ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                     : const Icon(Icons.picture_as_pdf),
                  label: Text(_isGeneratingPDF ? 'Génération...' : 'Générer la liste PDF des QR Codes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 🔹 Nouvelle page pour la gestion des notes (avec PDF)
class NotesScreen extends StatefulWidget {
  final List<QRCodeItem> allStudents; 
  const NotesScreen({required this.allStudents, super.key});

  @override
  _NotesScreenState createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  // Crée une copie de la liste initiale pour stocker les notes
  late List<QRCodeItem> _studentsWithNotes; 
  String _status = '';
  bool _isLoading = false;
  bool _isGeneratingPDF = false;

  @override
  void initState() {
    super.initState();
    // Important: Crée une copie profonde pour pouvoir modifier `note` localement
    _studentsWithNotes = widget.allStudents.map((item) => QRCodeItem(
      hash: item.hash,
      qrcode: item.qrcode,
      studentId: item.studentId,
      firstName: item.firstName,
      lastName: item.lastName,
      cin: item.cin,
      exam: item.exam,
      examDate: item.examDate,
      NINSCRI: item.NINSCRI,
      note: item.note, // Conserve la note si elle existe déjà
    )).toList();
  }

  Future<void> _uploadNotesFile() async {
    setState(() {
      _isLoading = true;
      _status = 'Sélection du fichier de notes...';
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
      setState(() => _status = 'Upload des notes en cours...');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8000/api/upload-notes'),
      );
      request.files.add(await http.MultipartFile.fromPath('excel_file', file.path));
      var response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      if (response.statusCode == 200 && jsonData['students'] != null) {
        
        final Map<String, double> notesMap = {};
        for (var studentData in (jsonData['students'] as List)) {
          String ninscri = studentData['numero_inscri']?.toString() ?? '';
          double? note = (studentData['note'] as num?)?.toDouble(); 
          if (ninscri.isNotEmpty && note != null) {
            notesMap[ninscri] = note;
          }
        }
        
        // Mise à jour de la liste locale (_studentsWithNotes)
        for (var student in _studentsWithNotes) {
          if (notesMap.containsKey(student.NINSCRI)) {
            // Puisque 'note' n'est plus final dans le modèle, cette ligne fonctionne
            student.note = notesMap[student.NINSCRI]; 
          }
        }

        setState(() {
          // Filtrer seulement ceux qui ont une note pour l'affichage du tableau
          _studentsWithNotes = _studentsWithNotes.where((s) => s.note != null).toList();
          _status = 'Notes mises à jour avec succès pour ${_studentsWithNotes.length} étudiants !';
          _isLoading = false;
        });
      } else {
        setState(() {
        final error = jsonData['error'] ?? 'Erreur lors de l\'upload (code ${response.statusCode})';
          _status = 'Erreur: $error';
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

  // FONCTION POUR GÉNÉRER LE PDF DES NOTES
  Future<void> _generateNotesPDF() async {
  if (_studentsWithNotes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Veuillez d\'abord importer un fichier de notes.')),
    );
    setState(() => _status = 'Aucun étudiant avec notes disponible.');
    return;
  }

  setState(() {
    _isGeneratingPDF = true;
    _status = 'Génération du PDF des notes en cours...';
  });

  try {
    // Préparer les données au format JSON
    final notesData = _studentsWithNotes
        .where((s) => s.note != null) // Filtrer les étudiants sans note
        .map((s) => s.toJson())
        .toList();

    if (notesData.isEmpty) {
      setState(() {
        _status = 'Aucune note valide à inclure dans le PDF.';
        _isGeneratingPDF = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune note valide à inclure dans le PDF.')),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/api/generate-notes-pdf'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'notes': notesData}),
    );

    if (response.statusCode == 200 &&
        response.headers['content-type']?.contains('application/pdf') == true) {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/notes_relevee.pdf';
      final file = File(filePath);

      await file.writeAsBytes(response.bodyBytes);

      setState(() {
        _status = 'PDF généré et sauvegardé avec succès !';
        _isGeneratingPDF = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF du Relevé de Notes généré et sauvegardé !')),
      );

      // Ouvrir le fichier PDF
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'ouverture du PDF : ${result.message}')),
        );
      }
    } else {
      final errorJson = jsonDecode(response.body);
      setState(() {
        _status = errorJson['error'] ?? 'Erreur lors de la génération du PDF (Code ${response.statusCode})';
        _isGeneratingPDF = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_status)),
      );
    }
  } catch (e) {
    setState(() {
      _status = 'Erreur lors de la génération du PDF : $e';
      _isGeneratingPDF = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur : $e')),
    );
    debugPrint('Erreur génération PDF: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gestion des Notes'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading || _isGeneratingPDF ? null : _uploadNotesFile,
                  icon: const Icon(Icons.upload),
                  label: Text(_isLoading ? 'Chargement...' : 'Importer les notes'),
                ),
                // NOUVEAU BOUTON PDF (Devient actif seulement si des notes ont été importées)
                ElevatedButton.icon(
                  onPressed: _studentsWithNotes.isEmpty || _isGeneratingPDF || _isLoading 
                      ? null 
                      : _generateNotesPDF,
                  icon: _isGeneratingPDF 
                     ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                     : const Icon(Icons.picture_as_pdf),
                  label: Text(_isGeneratingPDF ? 'Génération...' : 'Générer PDF des Notes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _status.contains('Erreur') ? Colors.red : Colors.green,
              ),
            ),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator())),
            if (_studentsWithNotes.isNotEmpty && !_isLoading)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                        columns: const [
                      DataColumn(label: Text('Num. Inscri.')),
                      DataColumn(label: Text('Nom')),
                      DataColumn(label: Text('Prénom')),
                      DataColumn(label: Text('CIN')),
                      DataColumn(label: Text('Examen')),
                      DataColumn(label: Text('Date Examen')),
                      DataColumn(label: Text('Note')),
                    ],
                      rows: _studentsWithNotes.map((student) {
                        return DataRow(
                          cells: [
                            DataCell(Text(student.NINSCRI)),
                            DataCell(Text(student.lastName)), 
                            DataCell(Text(student.firstName)), 
                            DataCell(Text(student.cin)), 
                            DataCell(Text(student.exam)), 
                            DataCell(Text(student.examDate)), 
                            DataCell(
                                Text(
                                    student.note == null 
                                        ? 'N/A' 
                                        : student.note!.toStringAsFixed(2),
                                    style: TextStyle(fontWeight: FontWeight.bold)
                                )
                            ), 
                        ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
