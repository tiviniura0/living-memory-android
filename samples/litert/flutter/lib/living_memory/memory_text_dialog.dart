import 'package:flutter/material.dart';

/// The route owns its controller until the dismissal animation has finished.
class MemoryTextDialog extends StatefulWidget {
  const MemoryTextDialog({super.key,required this.title,this.initialText='',
    this.hint='',this.lines=1,this.maxLength=700});
  final String title;
  final String initialText;
  final String hint;
  final int lines;
  final int maxLength;
  @override
  State<MemoryTextDialog> createState()=>_MemoryTextDialogState();
}

class _MemoryTextDialogState extends State<MemoryTextDialog> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller=TextEditingController(text:widget.initialText);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context)=>AlertDialog(
    title:Text(widget.title),
    content:TextField(controller:_controller,maxLines:widget.lines,maxLength:widget.maxLength,
      decoration:InputDecoration(labelText:'Texte',hintText:widget.hint)),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Annuler')),
      FilledButton(onPressed:()=>Navigator.pop(context,_controller.text.trim()),child:const Text('Enregistrer'))],
  );
}
