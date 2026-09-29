import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() => runApp(const FormApp());

class FormApp extends StatelessWidget {
  const FormApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DSA Palwal Form',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

// MODELS
class Question {
  String id, text, type;
  List<String> options;
  Question({required this.id, required this.text, required this.type, required this.options});
  Map toJson() => {'id': id, 'text': text, 'type': type, 'options': options};
  static Question fromJson(m) => Question(id: m['id'], text: m['text'], type: m['type'], options: List<String>.from(m['options']));
}

class FormData {
  String id, title, desc;
  List<Question> questions;
  FormData({required this.id, required this.title, required this.desc, required this.questions});
  Map toJson() => {'id': id, 'title': title, 'desc': desc, 'questions': questions.map((e) => e.toJson()).toList()};
  static FormData fromJson(m) => FormData(id: m['id'], title: m['title'], desc: m['desc'], questions: (m['questions'] as List).map((e) => Question.fromJson(e)).toList());
}

class ResponseData {
  String formId, formTitle;
  Map<String, String> answers;
  String date;
  ResponseData({required this.formId, required this.formTitle, required this.answers, required this.date});
  Map toJson() => {'formId': formId, 'formTitle': formTitle, 'answers': answers, 'date': date};
  static ResponseData fromJson(m) => ResponseData(formId: m['formId'], formTitle: m['formTitle'], answers: Map<String, String>.from(m['answers']), date: m['date']);
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
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int idx = 0;
  final pages = const [FormListPage(), ResponseListPage()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DSA Palwal - Offline Forms', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.deepPurple, centerTitle: true),
      body: pages[idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx, onTap: (i) => setState(() => idx = i), selectedItemColor: Colors.deepPurple,
        items: const [BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Forms'), BottomNavigationBarItem(icon: Icon(Icons.data_usage), label: 'Responses')],
      ),
      floatingActionButton: idx == 0? FloatingActionButton(backgroundColor: Colors.deepPurple, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateFormPage())).then((_) => setState(() {})), child: const Icon(Icons.add, color: Colors.white)) : null,
    );
  }
}

class FormListPage extends StatefulWidget {
  const FormListPage({super.key});
  @override
  State<FormListPage> createState() => _FormListPageState();
}

class _FormListPageState extends State<FormListPage> {
  List<FormData> forms = [];
  @override
  void initState() { super.initState(); load(); }
  load() async { forms = await Storage.getForms(); setState(() {}); }
  @override
  Widget build(BuildContext context) {
    if (forms.isEmpty) return const Center(child: Text('No Forms Yet\nClick + to Create', textAlign: TextAlign.center));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: forms.length,
      itemBuilder: (_, i) => Card(
        child: ListTile(
          leading: const Icon(Icons.description, color: Colors.deepPurple),
          title: Text(forms[i].title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${forms[i].desc}\n${forms[i].questions.length} Questions'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FillFormPage(form: forms[i]))),
        ),
      ),
    );
  }
}

class CreateFormPage extends StatefulWidget {
  const CreateFormPage({super.key});
  @override
  State<CreateFormPage> createState() => _CreateFormPageState();
}

class _CreateFormPageState extends State<CreateFormPage> {
  final titleC = TextEditingController();
  final descC = TextEditingController();
  List<Question> qs = [];

  void addQ() {
    final qC = TextEditingController();
    final optC = TextEditingController(text: 'Option 1, Option 2, Option 3, Option 4');
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Add Question'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: qC, decoration: const InputDecoration(labelText: 'Question')),
        const SizedBox(height: 10),
        TextField(controller: optC, decoration: const InputDecoration(labelText: 'Options (comma se alag)', helperText: 'Ex: Yes, No, Maybe')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          if(qC.text.isEmpty) return;
          setState(() { qs.add(Question(id: const Uuid().v4(), text: qC.text, type: 'mcq', options: optC.text.split(',').map((e) => e.trim()).toList())); });
          Navigator.pop(context);
        }, child: const Text('Add'))
      ],
    ));
  }

  save() async {
    if(titleC.text.isEmpty || qs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title aur kam se kam 1 Question daalo'))); return; }
    final forms = await Storage.getForms();
    forms.add(FormData(id: const Uuid().v4(), title: titleC.text, desc: descC.text, questions: qs));
    await Storage.saveForms(forms);
    if(mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form Saved Offline!'))); Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Form'), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Form Title *', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Questions (${qs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), ElevatedButton.icon(onPressed: addQ, icon: const Icon(Icons.add), label: const Text('Add Q'))]),
        const SizedBox(height: 10),
       ...qs.map((q) => Card(child: ListTile(title: Text(q.text), subtitle: Text(q.options.join(' | ')), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => qs.remove(q)))))),
        const SizedBox(height: 30),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.all(15)), onPressed: save, child: const Text('SAVE FORM OFFLINE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ]),
    );
  }
}

class FillFormPage extends StatefulWidget {
  final FormData form;
  const FillFormPage({super.key, required this.form});
  @override
  State<FillFormPage> createState() => _FillFormPageState();
}

class _FillFormPageState extends State<FillFormPage> {
  Map<String, String> ans = {};
  submit() async {
    if(ans.length!= widget.form.questions.length) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saare questions bharo'))); return; }
    await Storage.saveResponse(ResponseData(formId: widget.form.id, formTitle: widget.form.title, answers: ans, date: DateTime.now().toString().substring(0,19)));
    if(mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response Saved 100% Offline!'))); Navigator.pop(context); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.form.title), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(widget.form.desc, style: const TextStyle(color: Colors.grey)),
        const Divider(),
       ...widget.form.questions.map((q) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
           ...q.options.map((op) => RadioListTile<String>(title: Text(op), value: op, groupValue: ans[q.id], onChanged: (v) => setState(() => ans[q.id] = v!))),
          ])),
        )),
        const SizedBox(height: 20),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(16)), onPressed: submit, child
