// @dart=2.9

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/container.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_stream/sound_stream.dart';

import 'dart:io' show Platform;

// TODO import Dialogflow
import 'package:dialogflow_grpc/v2beta1.dart';
import 'package:dialogflow_grpc/generated/google/cloud/dialogflow/v2beta1/session.pb.dart';
import 'package:dialogflow_grpc/dialogflow_grpc.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';

import 'colors.dart';


class ChatPage extends StatefulWidget {
  //const ChatPage({super.key});
  ChatPage({Key key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}



enum TtsState { playing, stopped }
class _ChatPageState extends State<ChatPage> {
  //list of messages
  final List<ChatMessage> _messages = <ChatMessage>[];
  final TextEditingController _textController = TextEditingController();

  bool _isRecording = false;

  RecorderStream _recorder = RecorderStream();
  StreamSubscription _recorderStatus;
  StreamSubscription<List<int>> _audioStreamSubscription;
  BehaviorSubject<List<int>> _audioStream;

  // TODO DialogflowGrpc class instance
  DialogflowGrpcV2Beta1 dialogflow;
  


  @override
  void initState() {
    super.initState();
    initPlugin();
  
  }

  @override
  void dispose() {
    _recorderStatus?.cancel();
    _audioStreamSubscription?.cancel();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlugin() async {
    _recorderStatus = _recorder.status.listen((status) {
      if (mounted)
        setState(() {
          _isRecording = status == SoundStreamStatus.Playing;
        });
    });

    await Future.wait([
      _recorder.initialize()
    ]);

// TODO Get a Service account

    // Get a Service account
    final serviceAccount = ServiceAccount.fromString(
        (await rootBundle.loadString('assets/credentials.json')));
    // Create a DialogflowGrpc Instance
    dialogflow = DialogflowGrpcV2Beta1.viaServiceAccount(serviceAccount);

  }

void stopStream() async {
    await _recorder.stop();
    await _audioStreamSubscription?.cancel();
    await _audioStream?.close();
  }

  void handleSubmitted(text) async {
    print(text);
    _textController.clear();

    //TODO Dialogflow Code
    ChatMessage message = ChatMessage(
      text: text,
      name: "You",
      type: true,
    );
    setState(() {
      _messages.insert(0, message);
    });

    //get the response from Dialogflow
    DetectIntentResponse response = await dialogflow.detectIntent(text,"en-US");
    //get the message from Dialogflow
    String responseText = response.queryResult.fulfillmentText;
    //create a new message
    ChatMessage message2 = ChatMessage(
      text: responseText,
      name: "Bot",
      type: false,
    );
    //add the message to the list
    setState(() {
      _messages.insert(0, message2);
    
    });
    //speak the message
    //print("handleSubmitted"+responseText);
   // _speak(responseText);
  }

  void handleStream() async {
    _recorder.start();
    _audioStream = BehaviorSubject<List<int>>();
     _audioStreamSubscription = _recorder.audioStream.listen((data) {
      //print(data);
      _audioStream.add(data);
    });

    //TODO create speechContexts
    var biasList = SpeechContextV2Beta1(
        phrases: [
          'Dialogflow CX',
          'Dialogflow Essentials',
          'Action Builder',
          'HIPAA'
        ],
        boost: 20.0
    );

    // TODO Create and audio InputConfig
    //  See: https://cloud.google.com/dialogflow/es/docs/reference/rpc/google.cloud.dialogflow.v2#google.cloud.dialogflow.v2.InputAudioConfig
    var config = InputConfigV2beta1(
        encoding: 'AUDIO_ENCODING_LINEAR_16',
        languageCode: 'en-US',
        sampleRateHertz: 16000,
        singleUtterance: false,
        speechContexts: [biasList]
    );
    // TODO Make the streamingDetectIntent call, with the InputConfig and the audioStream
    final responseStream = dialogflow.streamingDetectIntent(config, _audioStream);

    // TODO Get the transcript and detectedIntent and show on screen
// Get the transcript and detectedIntent and show on screen
    responseStream.listen((data) {
      //print('----');
      setState(() {
        //print(data);
        String transcript = data.recognitionResult.transcript;
        String queryText = data.queryResult.queryText;
        String fulfillmentText = data.queryResult.fulfillmentText;

        if(fulfillmentText.isNotEmpty) {

          ChatMessage message = new ChatMessage(
            text: queryText,
            name: "You",
            type: true,
          );

          ChatMessage botMessage = new ChatMessage(
            text: fulfillmentText,
            name: "Bot",
            type: false,
          );
         
          _messages.insert(0, message);
          _textController.clear();
          _messages.insert(0, botMessage);

        }
        if(transcript.isNotEmpty) {
          _textController.text = transcript;
        }

      });
    },onError: (e){
      //print(e);
    },onDone: () {
      //print('done');
    });


  }

  // The chat interface
  //
  //------------------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        centerTitle: true,
        //title to include text and image
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            //space between text and image
           
             Image.asset(
              "assets/images/uonlogo.jpg",
              height: 25,

            ),
            SizedBox(
              width: 2,
            ),
            Text(
              "UoN Bot",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
           
          ],
        ),
        

        //title: Text("Bites ChatBot", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), ),
      ),


      body: Column(
        children: <Widget>[
          Flexible(
              child: ListView.builder(
                padding: EdgeInsets.all(8.0),
                reverse: true,
                itemBuilder: (_, int index) => _messages[index],
                itemCount: _messages.length,
              )),
          Divider(height: 1.0),
          Container(
              decoration: BoxDecoration(color: Theme.of(context).cardColor),
              child: IconTheme(
                data: IconThemeData(color: Theme.of(context).accentColor),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: <Widget>[
                      Flexible(
                        child: TextField(
                          controller: _textController,
                          onSubmitted: handleSubmitted,
                          decoration:
                          InputDecoration.collapsed(hintText: "Send a message"),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 4.0),
                        child: IconButton(
                          iconSize: 30.0,
                          icon: Icon(_isRecording ? Icons.mic : Icons.mic_off),
                          onPressed: () {
                            if(_isRecording){
                              stopStream();
                              setState(() {
                                _isRecording = false;
                              });
                            }else{
                              handleStream();
                              setState(() {
                                _isRecording = true;
                              });
                            }
                          },
                          //icon: Icon(Icons.mic),
                          //onPressed: () {
                          //  handleStream();
                          //},
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 4.0),
                        child: IconButton(
                          icon: Icon(Icons.send),
                          onPressed: () {
                            handleSubmitted(_textController.text);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
   
  }
}



//------------------------------------------------------------------------------------
// The chat message balloon
//
//------------------------------------------------------------------------------------
class ChatMessage extends StatelessWidget {

  ChatMessage({this.text, this.name, this.type});
  
  final String text;
  final String name;
  final bool type;
  
  final FlutterTts flutterTts = FlutterTts();
  speak(String text) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1);
    await flutterTts.speak(text);
  }

  @override 

  List<Widget> otherMessage(BuildContext context) {
    return <Widget>[
      new Container(
        margin: const EdgeInsets.only(right: 16.0),
        child: CircleAvatar(child: new Text('B')),
      ),
      new Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(this.name,
                style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              margin: const EdgeInsets.only(top: 5.0),
              child: Text(text),
            ),
            Container(
              margin: const EdgeInsets.only(top: 5.0),
              child: IconButton(
                icon: Icon(Icons.volume_up),
                onPressed: () {
                    speak(text);
                   
                },
              ),
            ),
          ],
        ),
      ),
      
    ];
  }


  List<Widget> myMessage(context) {
    return <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(name, style: Theme.of(context).textTheme.subtitle1),
            Container(
              margin: const EdgeInsets.only(top: 5.0),
              child: Text(text),
            ),
          ],
        ),
      ),
      Container(
        margin: const EdgeInsets.only(left: 16.0),
        child: CircleAvatar(
            child: Text(
              this.name[0],
              style: TextStyle(fontWeight: FontWeight.bold),
            )),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: this.type ? myMessage(context) : otherMessage(context),
      ),
    );
  }
  
  


  
}