import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/models/answer.dart';
import '../../../common/models/enum.dart';
import '../../../common/models/exceptions.dart';
import '../../../common/models/question.dart';
import '../../../common/models/student.dart';
import '../../../common/providers/all_students.dart';
import '../../../common/providers/login_information.dart';
import '../../../common/widgets/are_you_sure_dialog.dart';
import '../../../common/widgets/taking_action_notifier.dart';

class QuestionPart extends StatelessWidget {
  const QuestionPart({
    Key? key,
    required this.question,
    required this.questionView,
    required this.studentId,
    required this.answer,
    required this.isAnswerShown,
    required this.onTap,
    required this.onChangeQuestionRequest,
    required this.onStateChange,
  }) : super(key: key);

  final Question? question;
  final QuestionView questionView;
  final String? studentId;
  final Answer? answer;
  final bool isAnswerShown;
  final VoidCallback onTap;
  final VoidCallback onChangeQuestionRequest;
  final Function(VoidCallback) onStateChange;

  TextStyle _pickTextStyle(BuildContext context, Answer? answer) {
    if (answer == null) {
      return const TextStyle();
    }

    return TextStyle(
      color: answer.isAnswered ? Colors.black : Colors.red,
      fontWeight: answer.action(context) != ActionRequired.none
          ? FontWeight.bold
          : FontWeight.normal,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(question == null ? 'Nouvelle question' : question!.text,
          style: _pickTextStyle(context, answer)),
      trailing: _QuestionPartTrailing(
        question: question,
        onChangeQuestionRequest: onChangeQuestionRequest,
        questionView: questionView,
        studentId: studentId,
        onStateChange: onStateChange,
        hasAction: (answer?.action(context) ?? ActionRequired.none) !=
            ActionRequired.none,
        isAnswerShown: isAnswerShown,
      ),
      onTap: onTap,
    );
  }
}

class _QuestionPartTrailing extends StatefulWidget {
  const _QuestionPartTrailing({
    Key? key,
    required this.question,
    required this.onChangeQuestionRequest,
    required this.questionView,
    required this.studentId,
    required this.onStateChange,
    required this.hasAction,
    required this.isAnswerShown,
  }) : super(key: key);

  final Question? question;
  final VoidCallback onChangeQuestionRequest;
  final QuestionView questionView;
  final String? studentId;
  final Function(VoidCallback p1) onStateChange;
  final bool hasAction;
  final bool isAnswerShown;

  @override
  State<_QuestionPartTrailing> createState() => _QuestionPartTrailingState();
}

class _QuestionPartTrailingState extends State<_QuestionPartTrailing> {
  late final FlutterTts _textToSpeech;
  bool _isSpeaking = false;

  @override
  initState() {
    super.initState();
    _initTts();
  }

  Future _initTts() async {
    _textToSpeech = FlutterTts();
    await _textToSpeech.awaitSpeakCompletion(true);
    await _textToSpeech.setVolume(1);
    await _textToSpeech.setSpeechRate(0.5);
    await _textToSpeech.setPitch(1);
  }

  @override
  void dispose() {
    super.dispose();
    _stopRead();
  }

  Future _stopRead() async {
    await _textToSpeech.stop();
    _isSpeaking = false;
    if (mounted) setState(() {});
  }

  void _read() {
    _isSpeaking = true;
    _speak();
    setState(() {});
  }

  Future _speak() async {
    if (widget.question == null) return;
    _isSpeaking = true;

    await _textToSpeech.speak('La question est');
    await _textToSpeech.speak(widget.question!.text);

    final answer = _answer;
    int imageCounter = 1;
    if (answer == null || !widget.isAnswerShown) {
      _stopRead();
      return;
    }
    if (answer.discussion.isEmpty) {
      await _textToSpeech.speak('Il n\'y a aucune réponse.');
      _stopRead();
      return;
    }

    await _textToSpeech.speak(answer.discussion.length == 1
        ? 'La réponse est : '
        : 'Les réponses sont : ');
    for (final message in answer.discussion) {
      if (message.isPhotoUrl) {
        await _textToSpeech.speak('Photo $imageCounter de l\'élève.');
        imageCounter++;
      } else {
        await _textToSpeech.speak(message.text);
      }
    }
    _stopRead();
  }

  Answer? get _answer {
    final students = Provider.of<AllStudents>(context, listen: false);
    final student =
        widget.studentId == null ? null : students[widget.studentId];
    return student == null ? null : student.allAnswers[widget.question];
  }

  bool get _isQuestionActive {
    final students = Provider.of<AllStudents>(context, listen: false);

    return widget.questionView == QuestionView.modifyForAllStudents
        ? widget.question != null
            ? students.isQuestionActiveForAll(widget.question!)
            : false
        : _answer!.isActive;
  }

  @override
  Widget build(BuildContext context) {
    final loginType =
        Provider.of<LoginInformation>(context, listen: false).loginType;

    if (loginType == LoginType.student) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TakingActionNotifier(
            number: widget.hasAction ? 1 : null,
            forcedText: "?",
            borderColor: Colors.black,
            child: const Text(''),
          ),
          _isSpeaking
              ? IconButton(
                  onPressed: _stopRead, icon: const Icon(Icons.volume_off))
              : IconButton(onPressed: _read, icon: const Icon(Icons.volume_up)),
        ],
      );
    } else if (loginType == LoginType.teacher) {
      return widget.question == null
          ? _QuestionAddButton(
              newQuestionCallback: widget.onChangeQuestionRequest,
            )
          : widget.questionView != QuestionView.normal
              ? _QuestionActivatedState(
                  question: widget.question!,
                  studentId: widget.studentId,
                  initialStatus: _isQuestionActive,
                  onStateChange: widget.onStateChange,
                  questionView: widget.questionView,
                )
              : _QuestionValidateCheckmark(
                  question: widget.question!,
                  studentId: widget.studentId!,
                );
    } else {
      throw const NotLoggedIn();
    }
  }
}

class _QuestionAddButton extends StatelessWidget {
  const _QuestionAddButton({Key? key, required this.newQuestionCallback})
      : super(key: key);
  final VoidCallback newQuestionCallback;

  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: newQuestionCallback,
        icon: Icon(
          Icons.add_circle,
          color: Theme.of(context).colorScheme.primary,
        ));
  }
}

class _QuestionActivatedState extends StatefulWidget {
  const _QuestionActivatedState({
    Key? key,
    required this.studentId,
    required this.onStateChange,
    required this.initialStatus,
    required this.question,
    required this.questionView,
  }) : super(key: key);

  final String? studentId;
  final Question question;
  final bool initialStatus;
  final Function(VoidCallback) onStateChange;
  final QuestionView questionView;

  @override
  State<_QuestionActivatedState> createState() => _QuestionActivator();
}

class _QuestionActivator extends State<_QuestionActivatedState> {
  var _isActive = false;

  @override
  void initState() {
    super.initState();
    _isActive = widget.initialStatus;
  }

  Future<void> _toggleQuestionActiveState(value) async {
    final students = Provider.of<AllStudents>(context, listen: false);
    final student =
        widget.studentId == null ? null : students[widget.studentId];

    final sure = widget.questionView == QuestionView.modifyForAllStudents
        ? await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AreYouSureDialog(
                title: 'Confimer le choix',
                content:
                    'Voulez-vous vraiment ${value ? 'activer' : 'désactiver'} '
                    'cette question pour tous les élèves ?',
              );
            },
          )
        : true;

    if (!sure!) return;

    _isActive = value;
    if (student != null) {
      student.allAnswers[widget.question] =
          student.allAnswers[widget.question]!.copyWith(isActive: _isActive);
    } else {
      for (var student in students) {
        student.allAnswers[widget.question] =
            student.allAnswers[widget.question]!.copyWith(isActive: _isActive);
      }
    }
    widget.onStateChange(() {});
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Switch(onChanged: _toggleQuestionActiveState, value: _isActive);
  }
}

class _QuestionValidateCheckmark extends StatefulWidget {
  const _QuestionValidateCheckmark({
    Key? key,
    required this.question,
    required this.studentId,
  }) : super(key: key);

  final Question question;
  final String studentId;

  @override
  State<_QuestionValidateCheckmark> createState() =>
      _QuestionValidateCheckmarkState();
}

class _QuestionValidateCheckmarkState
    extends State<_QuestionValidateCheckmark> {
  void _validateAnswer(Student student, Answer answer) {
    // Reverse the status of the answer
    final newAnswer = answer.copyWith(
        isValidated: !answer.isValidated, actionRequired: ActionRequired.none);
    student.allAnswers[widget.question] = newAnswer;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final students = Provider.of<AllStudents>(context, listen: false);
    final student = students[widget.studentId];
    final answer = student.allAnswers[widget.question]!;
    return IconButton(
        onPressed: () => _validateAnswer(student, answer),
        icon: Icon(
          Icons.check,
          color: answer.isValidated ? Colors.green[600] : Colors.grey[300],
        ));
  }
}
