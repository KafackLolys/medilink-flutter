import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');
const secureStorage = FlutterSecureStorage();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthController(ApiClient(apiBaseUrl));
  await auth.restore();
  runApp(MedLinkApp(auth: auth));
}

class ApiClient {
  ApiClient(this.baseUrl);
  final String baseUrl;
  String? idToken;
  String? refreshToken;
  String tokenType = 'Bearer';
  Uri uri(String path) => Uri.parse(baseUrl + path);

  Future<http.Response> send(String path, String method, Map<String,dynamic>? body, {bool auth = true}) {
    final headers = <String,String>{'Accept':'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (auth && idToken != null) headers['Authorization'] = tokenType + ' ' + idToken!;
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'POST': return http.post(uri(path),headers:headers,body:encoded);
      case 'PATCH': return http.patch(uri(path),headers:headers,body:encoded);
      case 'DELETE': return http.delete(uri(path),headers:headers);
      default: return http.get(uri(path),headers:headers);
    }
  }

  dynamic decode(http.Response response) {
    dynamic value;
    try { value = response.body.isEmpty ? null : jsonDecode(response.body); }
    catch (_) { value = response.body; }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = value is Map ? value['message'] : null;
      throw ApiException(message is List ? message.join(', ') : message?.toString() ?? 'Erreur API', response.statusCode);
    }
    return value;
  }

  Future<dynamic> request(String path,{String method='GET',Map<String,dynamic>? body,bool authenticated=true}) async {
    var response = await send(path,method,body,auth:authenticated);
    if (response.statusCode == 401 && authenticated && refreshToken != null) {
      try {
        final refreshed = decode(await send('/auth/refresh','POST',{'refreshToken':refreshToken},auth:false)) as Map<String,dynamic>;
        idToken = refreshed['idToken'] as String?;
        refreshToken = refreshed['refreshToken'] as String?;
        tokenType = refreshed['tokenType'] as String? ?? 'Bearer';
        if (idToken != null) response = await send(path,method,body);
      } catch (_) {}
    }
    return decode(response);
  }

  Future<dynamic> createNeed(Map<String,dynamic> data) async {
    final request = http.MultipartRequest('POST',uri('/needs'));
    request.fields['data'] = jsonEncode(data);
    if (idToken != null) request.headers['Authorization'] = tokenType + ' ' + idToken!;
    return decode(await http.Response.fromStream(await request.send()));
  }
}

class ApiException implements Exception {
  ApiException(this.message,this.status);
  final String message; final int status;
  @override String toString()=>message;
}

class AuthController extends ChangeNotifier {
  AuthController(this.api);
  final ApiClient api;
  Map<String,dynamic>? user;
  bool busy=false;
  String? error;
  bool get signedIn=>user!=null && api.idToken!=null;
  String get role=>user?['role']?.toString()??'patient';
  String get name=>((user?['firstName']??'').toString()+' '+(user?['lastName']??'').toString()).trim();

  Future<void> restore() async {
    try {
      final raw=await secureStorage.read(key:'medilink_session');
      if(raw==null)return;
      final value=jsonDecode(raw) as Map<String,dynamic>;
      api.idToken=value['idToken'] as String?; api.refreshToken=value['refreshToken'] as String?;
      api.tokenType=value['tokenType'] as String? ?? 'Bearer'; user=Map<String,dynamic>.from(value['user'] as Map);
      if(api.idToken==null||api.refreshToken==null)await signOut(localOnly:true);
    } catch (_) { await signOut(localOnly:true); }
  }
  Future<void> persist() async => secureStorage.write(key:'medilink_session',value:jsonEncode({'user':user,'idToken':api.idToken,'refreshToken':api.refreshToken,'tokenType':api.tokenType}));
  Future<void> login(String email,String password) async {
    busy=true; error=null; notifyListeners();
    try { final value=await api.request('/auth/login',method:'POST',authenticated:false,body:{'email':email.trim(),'password':password}) as Map<String,dynamic>;
      user=Map<String,dynamic>.from(value['user'] as Map); api.idToken=value['idToken'] as String?; api.refreshToken=value['refreshToken'] as String?; api.tokenType=value['tokenType'] as String? ?? 'Bearer'; await persist();
    } catch(e){error=e.toString();}
    busy=false; notifyListeners();
  }
  Future<void> register(Map<String,dynamic> data) async {
    busy=true; error=null; notifyListeners();
    try { await api.request('/auth/register',method:'POST',authenticated:false,body:data); }
    catch(e){error=e.toString();}
    busy=false; notifyListeners();
  }
  Future<void> signOut({bool localOnly=false}) async {
    if(!localOnly && api.idToken!=null){try{await api.request('/auth/logout',method:'POST');}catch(_){}}
    user=null; api.idToken=null; api.refreshToken=null; await secureStorage.delete(key:'medilink_session'); notifyListeners();
  }
}

class MedLinkApp extends StatelessWidget {
  const MedLinkApp({super.key,required this.auth}); final AuthController auth;
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:auth,builder:(context,_)=>MaterialApp(
    title:'MedLink',debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff1769aa)).copyWith(secondary:const Color(0xff29b6a6)),scaffoldBackgroundColor:const Color(0xfff5f8fb),appBarTheme:const AppBarTheme(backgroundColor:Color(0xfff5f8fb),foregroundColor:Color(0xff17324d),surfaceTintColor:Colors.transparent,elevation:0,centerTitle:false),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:16),labelStyle:const TextStyle(color:Color(0xff66788a)),border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:Color(0xffe4ebf2))),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:Color(0xffe4ebf2))),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:Color(0xff1769aa),width:1.5))),filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(54),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),textStyle:const TextStyle(fontWeight:FontWeight.w700))),cardColor:Colors.white),
    home:auth.signedIn?HomeShell(auth:auth):LoginScreen(auth:auth)));
}

class LoginScreen extends StatefulWidget {const LoginScreen({super.key,required this.auth});final AuthController auth;@override State<LoginScreen> createState()=>_LoginState();}
class _LoginState extends State<LoginScreen> {
  final email=TextEditingController(),password=TextEditingController(),first=TextEditingController(),last=TextEditingController(),phone=TextEditingController(),specialty=TextEditingController(),license=TextEditingController();
  bool registering=false; String role='patient';
  Future<void> submit() async {
    if(registering){final data=<String,dynamic>{'firstName':first.text.trim(),'lastName':last.text.trim(),'phone':phone.text.trim(),'email':email.text.trim(),'password':password.text,'role':role};
      if(role=='doctor'){data['specialty']=specialty.text.trim();data['registrationNumber']=license.text.trim();}
      await widget.auth.register(data);
      if(mounted&&widget.auth.error==null){setState(()=>registering=false);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Compte créé. Connectez-vous.')));}
    } else {await widget.auth.login(email.text,password.text);}
    if(mounted&&widget.auth.error!=null)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(widget.auth.error!)));
  }
  @override void dispose(){email.dispose();password.dispose();first.dispose();last.dispose();phone.dispose();specialty.dispose();license.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Icon(LucideIcons.heartPulse,size:56,color:Color(0xff1769aa)),const SizedBox(height:8),Text('MedLink',textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:8),Text(registering?'Créer un compte':'La santé, plus proche de vous',textAlign:TextAlign.center),const SizedBox(height:28),
    if(registering)...[DropdownButtonFormField<String>(value:role,decoration:const InputDecoration(labelText:'Type de compte'),items:const [DropdownMenuItem(value:'patient',child:Text('Patient')),DropdownMenuItem(value:'doctor',child:Text('Médecin'))],onChanged:(v)=>setState(()=>role=v??'patient')),const SizedBox(height:12),TextField(controller:first,decoration:const InputDecoration(labelText:'Prénom')),const SizedBox(height:12),TextField(controller:last,decoration:const InputDecoration(labelText:'Nom')),const SizedBox(height:12),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Téléphone')),if(role=='doctor')... [const SizedBox(height:12),TextField(controller:specialty,decoration:const InputDecoration(labelText:'Spécialité')),const SizedBox(height:12),TextField(controller:license,decoration:const InputDecoration(labelText:'Numéro professionnel'))]],
    const SizedBox(height:12),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Adresse e-mail',prefixIcon:Icon(LucideIcons.mail))),const SizedBox(height:12),TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Mot de passe',prefixIcon:Icon(LucideIcons.lockKeyhole))),const SizedBox(height:20),
    FilledButton(onPressed:widget.auth.busy?null:submit,child:Padding(padding:const EdgeInsets.all(12),child:widget.auth.busy?const CircularProgressIndicator():Text(registering?'Créer mon compte':'Se connecter'))),TextButton(onPressed:()=>setState(()=>registering=!registering),child:Text(registering?'Déjà inscrit ? Se connecter':'Créer un compte')),
  ]))))));
}

class HomeShell extends StatefulWidget {const HomeShell({super.key,required this.auth});final AuthController auth;@override State<HomeShell> createState()=>_HomeShellState();}
class _HomeShellState extends State<HomeShell>{int selected=0;@override Widget build(BuildContext context){final doctor=widget.auth.role=='doctor';final pages=<Widget>[DashboardScreen(auth:widget.auth),doctor?NeedsScreen(auth:widget.auth,doctor:true):DoctorsScreen(auth:widget.auth),NeedsScreen(auth:widget.auth,doctor:doctor),AppointmentsScreen(auth:widget.auth,doctor:doctor)];final labels=doctor?const ['Accueil','Demandes','Mes demandes','Rendez-vous']:const ['Accueil','Médecins','Mes besoins','Rendez-vous'];final icons=const [LucideIcons.house,LucideIcons.stethoscope,LucideIcons.clipboardList,LucideIcons.calendarDays];return Scaffold(appBar:AppBar(title:const Text('MedLink',style:TextStyle(fontWeight:FontWeight.bold)),actions:[IconButton(tooltip:'Déconnexion',onPressed:()=>widget.auth.signOut(),icon:const Icon(LucideIcons.logOut))]),body:IndexedStack(index:selected,children:pages),bottomNavigationBar:NavigationBar(selectedIndex:selected,onDestinationSelected:(v)=>setState(()=>selected=v),destinations:List.generate(4,(i)=>NavigationDestination(icon:Icon(icons[i]),label:labels[i]))),floatingActionButton:!doctor&&selected==2?FloatingActionButton.extended(onPressed:()=>createNeed(context,widget.auth),icon:const Icon(LucideIcons.plus),label:const Text('Nouveau besoin')):null);}}

class DashboardScreen extends StatelessWidget {const DashboardScreen({super.key,required this.auth});final AuthController auth;@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.fromLTRB(20,12,20,28),children:[Text('Bonjour'+(auth.name.isEmpty?'':', '+auth.name),style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800,color:const Color(0xff17324d),letterSpacing:-.4)),const SizedBox(height:6),Text(auth.role=='doctor'?'Votre espace médecin':'Votre espace santé'),const SizedBox(height:20),Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff1769aa),Color(0xff238ac4)],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(24),boxShadow:[BoxShadow(color:const Color(0xff1769aa).withOpacity(.18),blurRadius:22,offset:const Offset(0,10))]),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:Colors.white.withOpacity(.16),borderRadius:BorderRadius.circular(20)),child:const Text('VOTRE SANTÉ, EN CONFIANCE',style:TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w700,letterSpacing:1))),const SizedBox(height:14),Text(auth.role=='doctor'?'Accompagnez vos patients.':'Un accompagnement de santé, plus simple.',style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w700,height:1.25)),const SizedBox(height:8),Text(auth.role=='doctor'?'Consultez les demandes et proposez votre expertise.':'Décrivez votre besoin pour recevoir des propositions adaptées.',style:const TextStyle(color:Color(0xffe5f4ff),height:1.45))])),const SizedBox(width:10),Container(width:48,height:48,decoration:BoxDecoration(color:Colors.white.withOpacity(.15),borderRadius:BorderRadius.circular(16)),child:const Icon(LucideIcons.heartPulse,color:Colors.white,size:25))])),const SizedBox(height:18),Text('Vos raccourcis',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800,color:const Color(0xff17324d))),const SizedBox(height:12),quick(context,'Trouver un médecin','Profils et spécialités',LucideIcons.search,DoctorsScreen(auth:auth)),quick(context,'Mes besoins médicaux','Demandes et propositions',LucideIcons.clipboardList,NeedsScreen(auth:auth,doctor:auth.role=='doctor')),quick(context,'Rendez-vous','Consultez votre agenda',LucideIcons.calendarDays,AppointmentsScreen(auth:auth,doctor:auth.role=='doctor'))]);Widget quick(BuildContext c,String title,String sub,IconData icon,Widget page)=>Card(child:ListTile(leading:CircleAvatar(child:Icon(icon)),title:Text(title),subtitle:Text(sub),trailing:const Icon(LucideIcons.chevronRight),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>page))));}

class DoctorsScreen extends StatelessWidget {const DoctorsScreen({super.key,required this.auth});final AuthController auth;@override Widget build(BuildContext context)=>ApiList(api:auth.api,path:'/public/doctors/recommended',title:'Médecins recommandés',empty:'Aucun médecin disponible',item:(row)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(LucideIcons.stethoscope)),title:Text(row['name']?.toString()??'Médecin'),subtitle:Text([row['specialty'],row['city'],row['rating']==null?null:'Note '+row['rating'].toString()].whereType<Object>().join(' • ')),trailing:const Icon(LucideIcons.badgeCheck,color:Colors.blue))));}}
class NeedsScreen extends StatelessWidget {const NeedsScreen({super.key,required this.auth,required this.doctor});final AuthController auth;final bool doctor;@override Widget build(BuildContext context)=>ApiList(api:auth.api,path:doctor?'/needs/doctor':'/needs',title:doctor?'Demandes de patients':'Mes besoins médicaux',empty:'Aucune demande à afficher',item:(row)=>NeedCard(api:auth.api,row:row,doctor:doctor));}
class NeedCard extends StatelessWidget {const NeedCard({super.key,required this.api,required this.row,required this.doctor});final ApiClient api;final Map<String,dynamic> row;final bool doctor;@override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(row['title']?.toString()??'Besoin médical',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold))),if(row['priority']!=null)Chip(label:Text(row['priority'].toString()))]),if(row['description']!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(row['description'].toString(),maxLines:3,overflow:TextOverflow.ellipsis)),const SizedBox(height:10),if(row['status']!=null)Chip(label:Text(row['status'].toString())),if(doctor)Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>propose(context),icon:const Icon(LucideIcons.send),label:const Text('Faire une proposition')))])));
  Future<void> propose(BuildContext context)async{final message=TextEditingController(),fee=TextEditingController();final key=GlobalKey<FormState>();final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Proposer un rendez-vous'),content:Form(key:key,child:Column(mainAxisSize:MainAxisSize.min,children:[TextFormField(controller:message,decoration:const InputDecoration(labelText:'Message'),validator:(v)=>v==null||v.trim().isEmpty?'Message requis':null),TextFormField(controller:fee,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Honoraires'),validator:(v)=>double.tryParse(v??'')==null?'Montant invalide':null)])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Annuler')),FilledButton(onPressed:()=>key.currentState!.validate()?Navigator.pop(c,true):null,child:const Text('Envoyer'))]));if(ok!=true)return;try{await api.request('/needs/doctor/'+(row['id']??'').toString()+'/proposals',method:'POST',body:{'message':message.text.trim(),'fee':double.parse(fee.text),'currency':'XAF','consultationMode':'home'});if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Proposition envoyée')));}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
}

class AppointmentsScreen extends StatelessWidget {const AppointmentsScreen({super.key,required this.auth,required this.doctor});final AuthController auth;final bool doctor;@override Widget build(BuildContext context)=>ApiList(api:auth.api,path:doctor?'/appointments/doctor':'/appointments',title:'Rendez-vous',empty:'Aucun rendez-vous programmé',item:(row)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(LucideIcons.calendarCheck)),title:Text(row['doctorName']?.toString()??row['patientName']?.toString()??'Consultation'),subtitle:Text((row['scheduledAt']??'Date à confirmer').toString()+'
'+(row['status']??'En attente').toString()),isThreeLine:true)));}}

class ApiList extends StatefulWidget {const ApiList({super.key,required this.api,required this.path,required this.title,required this.empty,required this.item});final ApiClient api;final String path,title,empty;final Widget Function(Map<String,dynamic>) item;@override State<ApiList> createState()=>_ApiListState();}
class _ApiListState extends State<ApiList>{late Future<List<Map<String,dynamic>>> future;@override void initState(){super.initState();future=load();}Future<List<Map<String,dynamic>>> load()async{final value=await widget.api.request(widget.path);if(value is List)return value.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();if(value is Map){for(final candidate in value.values){if(candidate is List)return candidate.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();}}return [];}void retry()=>setState(()=>future=load());@override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,state){if(state.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());if(state.hasError)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(LucideIcons.cloudOff,size:40),const SizedBox(height:12),Text(state.error.toString(),textAlign:TextAlign.center),TextButton(onPressed:retry,child:const Text('Réessayer'))])));final rows=state.data??[];return RefreshIndicator(onRefresh:()async=>retry(),child:ListView(padding:const EdgeInsets.fromLTRB(20,16,20,28),children:[Text(widget.title,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800,color:const Color(0xff17324d))),const SizedBox(height:18),if(rows.isEmpty)Padding(padding:const EdgeInsets.all(48),child:Center(child:Text(widget.empty)))else ...rows.map(widget.item)]));});}

Future<void> createNeed(BuildContext context,AuthController auth)async{final title=TextEditingController(),description=TextEditingController(),specialty=TextEditingController(),district=TextEditingController();final key=GlobalKey<FormState>();final ok=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,builder:(c)=>Padding(padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(c).viewInsets.bottom+20),child:Form(key:key,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text('Décrire mon besoin',style:Theme.of(c).textTheme.titleLarge),const SizedBox(height:14),TextFormField(controller:title,decoration:const InputDecoration(labelText:'Titre'),validator:(v)=>v==null||v.trim().isEmpty?'Champ requis':null),const SizedBox(height:10),TextFormField(controller:specialty,decoration:const InputDecoration(labelText:'Spécialité'),validator:(v)=>v==null||v.trim().isEmpty?'Champ requis':null),const SizedBox(height:10),TextFormField(controller:district,decoration:const InputDecoration(labelText:'Quartier / district'),validator:(v)=>v==null||v.trim().isEmpty?'Champ requis':null),const SizedBox(height:10),TextFormField(controller:description,minLines:3,maxLines:5,decoration:const InputDecoration(labelText:'Votre situation'),validator:(v)=>v==null||v.trim().isEmpty?'Champ requis':null),const SizedBox(height:14),FilledButton(onPressed:()=>key.currentState!.validate()?Navigator.pop(c,true):null,child:const Text('Publier'))]))));if(ok!=true)return;try{await auth.api.createNeed({'title':title.text.trim(),'description':description.text.trim(),'specialty':specialty.text.trim(),'district':district.text.trim(),'priority':'normal','mode':'tele'});if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Demande envoyée')));}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Publication impossible : '+e.toString())));}}
