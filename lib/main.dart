import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const FormApp());

class FormApp extends StatelessWidget {
  const FormApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DSA Palwal PRO',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

// MODELS - Advance
class Question {
  String id, text, type;
  List<String> options;
  Question({required this.id, required this.text, required this.type, required this.options});
  Map toJson() => {'id': id, 'text': text, 'type': type, 'options': options};
  static Question fromJson(Map m) => Question(id: m['id'], text: m['text'], type: m['type'], options: List<String>.from(m['options']?? []));
}

class FormData {
  String id, title, desc;
  List<Question> questions;
  String createdAt;
  FormData({required this.id, required this.title, required this.desc, required this.questions, required this.createdAt});
  Map toJson() => {'id': id, 'title': title, 'desc': desc, 'questions': questions.map((e) => e.toJson()).toList(), 'createdAt': createdAt};
  static FormData fromJson(Map m) => FormData(id: m['id'], title: m['title'], desc: m['desc']?? '', questions: (m['questions'] as List).map((e) => Question.fromJson(e)).toList(), createdAt: m['createdAt']?? '');
}

class ResponseData {
  String formId, formTitle, date, gps, address, photo;
  Map<String, dynamic> answers;
  ResponseData({required this.formId, required this.formTitle, required this.answers, required this.date, required this.gps, required this.address, required this.photo});
  Map toJson() => {'formId': formId, 'formTitle': formTitle, 'answers': answers, 'date': date, 'gps': gps, 'address': address, 'photo': photo};
  static ResponseData fromJson(Map m) => ResponseData(formId: m['formId'], formTitle: m['formTitle'], answers: Map<String, dynamic>.from(m['answers']), date: m['date'], gps: m['gps']?? '', address: m['address']?? '', photo: m['photo']?? '');
}

// STORAGE
class Storage {
  static Future<List<FormData>> getForms() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('forms')?? [];
    return list.map((e) => FormData.fromJson(jsonDecode(e))).toList();
  }
  static Future saveForms(List<FormData> forms) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('forms', forms.map((e) => jsonEncode(e.toJson())).toList());
  }
  static Future<List<ResponseData>> getResponses() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('responses')?? [];
    return list.map((e) => ResponseData.fromJson(jsonDecode(e))).toList();
  }
  static Future saveResponse(ResponseData r) async {
    final p = await SharedPreferences.getInstance();
    final old = await getResponses();
    old.add(r);
    await p.setStringList('responses', old.map((e) => jsonEncode(e.toJson())).toList());
  }
}

// HOME
class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeState(); }
class _HomeState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController tab;
  List<FormData> forms = [];
  List<ResponseData> resps = [];
  @override void initState() { super.initState(); tab = TabController(length: 2, vsync: this); _load(); }
  _load() async { forms = await Storage.getForms(); resps = await Storage.getResponses(); setState(() {}); }

  Future<String> getLocationFull() async {
    try {
      bool service = await Geolocator.isLocationServiceEnabled();
      if (!service) return "GPS Off है";
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) return "Permission denied";
      var pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String addr = placemarks.isNotEmpty? "${placemarks[0].street}, ${placemarks[0].locality}" : "";
      return "${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}|$addr";
    } catch (e) { return "GPS Error"; }
  }

  Future<void> exportExcel() async {
    if (resps.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कोई data नहीं'))); return; }
    var excel = Excel.createExcel();
    var sheet = excel['DSA_Palwal_PRO'];
    sheet.appendRow([TextCellValue('Form'), TextCellValue('Date'), TextCellValue('GPS'), TextCellValue('Address'), TextCellValue('Photo'), TextCellValue('Answers JSON')]);
    for (var r in resps) {
      sheet.appendRow([TextCellValue(r.formTitle), TextCellValue(DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(r.date))), TextCellValue(r.gps), TextCellValue(r.address), TextCellValue(r.photo.split('/').last), TextCellValue(jsonEncode(r.answers))]);
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = "${dir.path}/DSA_Palwal_PRO_${DateFormat('ddMM_HHmm').format(DateTime.now())}.xlsx";
    File(path).writeAsBytesSync(excel.encode()!);
    await Share.shareXFiles([XFile(path)], text: 'DSA Palwal PRO - All Data Export');
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DSA Palwal PRO - Advance'), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
        bottom: TabBar(controller: tab, tabs: const [Tab(icon: Icon(Icons.list_alt), text: 'Forms'), Tab(icon: Icon(Icons.cloud_done), text: 'Responses')]),
        actions: [IconButton(onPressed: exportExcel, icon: const Icon(Icons.download), tooltip: 'Excel Export')]),
      body: TabBarView(controller: tab, children: [buildForms(), buildResps()]),
      floatingActionButton: FloatingActionButton.extended(onPressed: createForm, icon: const Icon(Icons.add), label: const Text('New Advance Form')),
    );
  }

  Widget buildForms() {
    if (forms.isEmpty) return const Center(child: Text('New Advance Form दबाओ\nPhoto + GPS + 3 Option + Excel', textAlign: TextAlign.center));
    return ListView.builder(itemCount: forms.length, itemBuilder: (c, i) => Card(margin: const EdgeInsets.all(8), child: ListTile(leading: const Icon(Icons.assignment, color: Colors.deepPurple), title: Text(forms[i].title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${forms[i].desc}\n${forms[i].questions.length} Questions | ${DateFormat('dd/MM').format(DateTime.parse(forms[i].createdAt))}"), isThreeLine: true, trailing: PopupMenuButton(itemBuilder: (c) => [const PopupMenuItem(value: 'del', child: Text('Delete'))], onSelected: (v) async { forms.removeAt(i); await Storage.saveForms(forms); setState(() {}); }), onTap: () => fillForm(forms[i]))));
  }

  Widget buildResps() {
    if (resps.isEmpty) return const Center(child: Text('कोई Response नहीं'));
    return ListView.builder(itemCount: resps.length, itemBuilder: (c, i) { final r = resps[resps.length - 1 - i]; return Card(child: ListTile(title: Text(r.formTitle), subtitle: Text("${DateFormat('dd/MM hh:mm a').format(DateTime.parse(r.date))}\nGPS: ${r.gps}\n${r.address}", maxLines: 3), leading: r.photo.isNotEmpty? Image.file(File(r.photo), width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (a,b,d) => const Icon(Icons.image)) : const Icon(Icons.location_on))); }); }
  }

  void createForm() {
    final titleC = TextEditingController(); final descC = TextEditingController(); List<Question> qs = [];
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('Advance Form बनाओ'), content: SizedBox(width: 400, height: 500, child: SingleChildScrollView(child: Column(children: [
        TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Form Title *', border: OutlineInputBorder())),
        const SizedBox(height: 8), TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
        const SizedBox(height: 12), const Text('Features: Auto Photo + GPS + Excel Export', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 12)),
        const Divider(),
       ...qs.map((q) => Card(color: Colors.deepPurple.shade50, child: ListTile(title: Text(q.text), subtitle: Text("Type: ${q.type} | Options: ${q.options.join(', ')}")))),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ElevatedButton.icon(onPressed: () { final qc = TextEditingController(); showDialog(context: ctx, builder: (c2) => AlertDialog(title: const Text('Text Question'), content: TextField(controller: qc, decoration: const InputDecoration(labelText: 'सवाल लिखो')), actions: [ElevatedButton(onPressed: () { if (qc.text.isNotEmpty) { setS(() => qs.add(Question(id: const Uuid().v4(), text: qc.text, type: 'text', options: []))); Navigator.pop(c2); } }, child: const Text('Add'))])); }, icon: const Icon(Icons.text_fields, size: 18), label: const Text('Text')),
          ElevatedButton.icon(onPressed: () { final qc = TextEditingController(); final oc = TextEditingController(text: 'हाँ, नहीं, पता नहीं'); showDialog(context: ctx, builder: (c2) => AlertDialog(title: const Text('3 Option एक साथ'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: qc, decoration: const InputDecoration(labelText: 'सवाल?')), const SizedBox(height: 8), TextField(controller: oc, decoration: const InputDecoration(labelText: '3 Options - comma से लिखो'))]), actions: [ElevatedButton(onPressed: () { if (qc.text.isNotEmpty) { setS(() => qs.add(Question(id: const Uuid().v4(), text: qc.text, type: 'radio3', options: oc.text.split(',').map((e) => e.trim()).toList()))); Navigator.pop(c2); } }, child: const Text('Add 3 Option'))])); }, icon: const Icon(Icons.radio_button_checked, size: 18), label: const Text('3 Option'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade100)),
          ElevatedButton.icon(onPressed: () { final qc = TextEditingController(); showDialog(context: ctx, builder: (c2) => AlertDialog(title: const Text('Number Question'), content: TextField(controller: qc), actions: [ElevatedButton(onPressed: () { setS(() => qs.add(Question(id: const Uuid().v4(), text: qc.text, type: 'number', options: []))); Navigator.pop(c2); }, child: const Text('Add'))])); }, icon: const Icon(Icons.numbers, size: 18), label: const Text('Number')),
          ElevatedButton.icon(onPressed: () { final qc = TextEditingController(); showDialog(context: ctx, builder: (c2) => AlertDialog(title: const Text('Photo Question'), content: TextField(controller: qc, decoration: const InputDecoration(labelText: 'जैसे - अपनी फोटो लो')), actions: [ElevatedButton(onPressed: () { setS(() => qs.add(Question(id: const Uuid().v4(), text: qc.text, type: 'photo', options: []))); Navigator.pop(c2); }, child: const Text('Add'))])); }, icon: const Icon(Icons.camera_alt, size: 18), label: const Text('Photo')),
        ])
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), ElevatedButton(onPressed: () async { if (titleC.text.isEmpty) return; final newForm = FormData(id: const Uuid().v4(), title: titleC.text, desc: descC.text, questions: qs, createdAt: DateTime.now().toIso8601String()); forms.add(newForm); await Storage.saveForms(forms); setState(() {}); Navigator.pop(ctx); }, child: const Text('Save Advance Form'))],
    )));
  }

  void fillForm(FormData form) {
    Map<String, dynamic> ans = {}; String gps = ""; String address = ""; String mainPhoto = ""; final picker = ImagePicker(); bool loadingGps = false;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: Text(form.title), content: SizedBox(width: 400, height: 600, child: SingleChildScrollView(child: Column(children: [
        Card(color: Colors.green.shade50, child: ListTile(leading: const Icon(Icons.gps_fixed, color: Colors.green), title: const Text('GPS Location (Advance)'), subtitle: Text(gps.isEmpty? "GPS Capture करो" : "$gps\n$address"), trailing: loadingGps? const CircularProgressIndicator() : ElevatedButton(onPressed: () async { setS(() => loadingGps = true); String loc = await getLocationFull(); List<String> parts = loc.split('|'); setS(() { gps = parts[0]; address = parts.length > 1? parts[1] : ""; loadingGps = false; }); }, child: const Text('GPS लो')))),
        Card(color: Colors.blue.shade50, child: ListTile(leading: const Icon(Icons.camera_alt, color: Colors.blue), title: const Text('Main Photo Upload'), subtitle: Text(mainPhoto.isEmpty? "कोई फोटो नहीं" : mainPhoto.split('/').last), trailing: ElevatedButton(onPressed: () async { final XFile? img = await picker.pickImage(source: ImageSource.camera, imageQuality: 70); if (img!= null) setS(() => mainPhoto = img.path); }, child: const Text('Photo')))),
        const Divider(),
       ...form.questions.map((q) {
          if (q.type == 'radio3') {
            return Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(q.text, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6),...q.options.map((op) => RadioListTile<String>(title: Text(op), value: op, groupValue: ans[q.id], onChanged: (v) => setS(() => ans[q.id] = v), dense: true)))])));
          } else if (q.type == 'photo') {
            return Card(child: ListTile(title: Text(q.text), subtitle: Text(ans[q.id]!= null? "Photo ली गई" : "Photo नहीं"), trailing: IconButton(icon: const Icon(Icons.camera), onPressed: () async { final XFile? img = await picker.pickImage(source: ImageSource.camera); if (img!= null) setS(() => ans[q.id] = img.path); })));
          } else if (q.type == 'number') {
            return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: TextField(keyboardType: TextInputType.number, decoration: InputDecoration(labelText: q.text, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.numbers)), onChanged: (v) => ans[q.id] = v));
          } else {
            return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: TextField(decoration: InputDecoration(labelText: q.text, border: const OutlineInputBorder()), onChanged: (v) => ans[q.id] = v, maxLines: q.type == 'text'? 1 : 3));
          }
        }).toList(),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), ElevatedButton.icon(icon: const Icon(Icons.save), label: const Text('Submit PRO'), onPressed: () async { final resp = ResponseData(formId: form.id, formTitle: form.title, answers: ans, date: DateTime.now().toIso8601String(), gps: gps, address: address, photo: mainPhoto); await Storage.saveResponse(resp); resps = await Storage.getResponses(); setState(() {}); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Advance Data Saved! Photo + GPS + Excel Ready'))); })],
    )));
  }
}
