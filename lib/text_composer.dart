import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
//import 'package:wechat_camera_picker/wechat_camera_picker.dart';

class TextComposer extends StatefulWidget {
  TextComposer(this.sendMessage);

  final Function({String? text, File? imgFile })
      sendMessage;

  @override
  _TextComposerState createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  final TextEditingController _controller = TextEditingController();
  bool _isComposing = false;
  final ImagePicker _picker = ImagePicker();


  void _reset() {
    _controller.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo_camera),
            onPressed: () async {
              final XFile? _imgFile =
                  await _picker.pickImage(source: ImageSource.camera);

              if (_imgFile == null) {
                return;
              }else {
                File file = File(_imgFile.path);
                widget.sendMessage(imgFile: file);
              }
            },

          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration.collapsed(
                  hintText: "Enviar uma mensagem"),
              onChanged: (text) {
                setState(() {
                  _isComposing = text
                      .isNotEmpty; //Passa para o _isComposing o valor de True por não estar vazio o campo
                });
              },
              onSubmitted: (text) {
                widget.sendMessage(text: text);
                _reset();
              },
            ),
          ),
          IconButton(
            onPressed: !_isComposing
                ? null
                : () {
                    widget.sendMessage(text: _controller.text);
                    _reset();
                  },
            icon: const Icon(Icons.send),
          )
        ],
      ),
    );
  }
}
