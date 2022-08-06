import 'dart:io';
import 'package:chat/chat_message.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chat/text_composer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  User? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    //Sempre que a autenticação mudar ele mudará o State
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _currentUser = user;
      });
    });
  }

  Future _getUser() async {
    //Verificação  se o usuário está logado.
    if (_currentUser != null) return _currentUser;
    try {
      //Tentando fazer SignIn no google
      final GoogleSignInAccount? googleSignInAccount =
          await googleSignIn.signIn();
      //Pegando os dados de autenticação do Google
      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignInAccount!.authentication;
      //Passando os valores de atenticação do google para o Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleSignInAuthentication.idToken,
          accessToken: googleSignInAuthentication.accessToken);
      //Fazendo o login no Firebase
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      //Passando todos dados do usuario do firebase para 'user'
      final User? user = userCredential.user;

      return user;
    } catch (error) {
      return null;
    }
  }

  void _sendMessage({String? text, File? imgFile}) async {
    final User? user = await _getUser();

    //Caso a autenticação der erro e não carregar o usuário
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Não foi possível fazer o login. Tente novamente"),
          backgroundColor: Colors.red,
        ),
      );
    }

    //Inserindo os dados no Firebase
    Map<String, dynamic> data = {
      "uid": user!.uid,
      "senderName": user.displayName,
      "senderPhotoUrl": user.photoURL,
      'time': Timestamp.now(),
    };

    // Verificando se há imagem
    if (imgFile != null) {
      firebase_storage.UploadTask task = firebase_storage
          .FirebaseStorage.instance
          .ref()
          .child(user.uid)
          .child(DateTime.now().microsecondsSinceEpoch.toString())
          .putFile(imgFile);

      setState(() {
        _isLoading = true;
      });

      firebase_storage.TaskSnapshot taskSnapshot = await task;
      String url = await taskSnapshot.ref.getDownloadURL();
      data['imgUrl'] = url;

      setState(() {
        _isLoading = false;
      });
    }

    if (text != null) data['text'] = text;

    //Adicionando os dados do MAP DATA no firebase com a coleção chamada messages
    FirebaseFirestore.instance.collection('messages').add(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        centerTitle: true,
        title: Text(_currentUser == null
            ? 'Chat App'
            : 'Olá, ${_currentUser?.displayName}'),
        elevation: 0,
        actions: [
          _currentUser != null
              ? IconButton(
                  icon: Icon(Icons.exit_to_app),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    googleSignIn.signOut();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Você saiu com sucesso.",
                        ),
                      ),
                    );
                  },
                )
              : Container()
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('messages')
                    .orderBy('time')
                    .snapshots(),
                builder: (context, snapshot) {
                  switch (snapshot.connectionState) {
                    case ConnectionState.none:
                    case ConnectionState.waiting:
                      return const Center(
                        child: const CircularProgressIndicator(),
                      );
                    default:
                      List message = snapshot.data!.docs.reversed.toList();

                      //construindo a tela do chat
                      return ListView.builder(
                        itemCount: message.length,
                        reverse: true,
                        // Invertendo para inserção de mensagens de baixo para cima
                        itemBuilder: (context, index) {
                          return ChatMessage(
                              message[index].data(),
                              message[index].data()["uid"] ==
                                  _currentUser?.uid);
                        },
                      );
                  }
                }),
          ),
          _isLoading ? LinearProgressIndicator() : Container(),
          TextComposer(_sendMessage),
        ],
      ),
    );
  }
}
