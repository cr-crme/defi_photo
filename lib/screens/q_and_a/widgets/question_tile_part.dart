import 'package:flutter/material.dart';
import 'package:mon_stage_en_images/common/models/answer.dart';
import 'package:mon_stage_en_images/common/models/database.dart';
import 'package:mon_stage_en_images/common/models/enum.dart';
import 'package:mon_stage_en_images/common/models/exceptions.dart';
import 'package:mon_stage_en_images/common/models/question.dart';
import 'package:mon_stage_en_images/common/providers/all_answers.dart';
import 'package:mon_stage_en_images/common/providers/all_questions.dart';
import 'package:mon_stage_en_images/common/widgets/are_you_sure_dialog.dart';
import 'package:mon_stage_en_images/common/widgets/taking_action_notifier.dart';
import 'package:provider/provider.dart';

class QuestionPart extends StatelessWidget {
  const QuestionPart({
    super.key,
    required this.question,
    required this.viewSpan,
    required this.pageMode,
    required this.studentId,
    required this.answer,
    required this.isAnswerShown,
    required this.onTap,
    required this.onStateChange,
    required this.isReading,
    required this.startReadingCallback,
    required this.stopReadingCallback,
  });

  final Question? question;
  final Target viewSpan;
  final PageMode pageMode;
  final String? studentId;
  final Answer? answer;
  final bool isAnswerShown;
  final VoidCallback onTap;
  final VoidCallback onStateChange;
  final bool isReading;
  final VoidCallback startReadingCallback;
  final VoidCallback stopReadingCallback;

  TextStyle _pickTextStyle(BuildContext context, Answer? answer) {
    if (answer == null) {
      final answers = Provider.of<AllAnswers>(context, listen: false);

      return TextStyle(
        color: question != null && answers.isQuestionInactiveForAll(question!)
            ? Colors.grey
            : Colors.black,
        fontSize: 18,
        height: 1.40,
      );
    }

    return TextStyle(
      color: answer.isActive ? Colors.black : Colors.grey,
      fontWeight: answer.action(context) != ActionRequired.none
          ? FontWeight.bold
          : FontWeight.normal,
      fontSize: 18,
      height: 1.40,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(question == null ? 'Nouvelle question' : question!.text,
          style: _pickTextStyle(context, answer)),
      trailing: _QuestionPartTrailing(
        question: question,
        onNewQuestion: onTap,
        viewSpan: viewSpan,
        pageMode: pageMode,
        studentId: studentId,
        onStateChange: onStateChange,
        hasAction: (answer?.action(context) ?? ActionRequired.none) !=
            ActionRequired.none,
        isAnswerShown: isAnswerShown,
        isReading: isReading,
        startReadingCallback: startReadingCallback,
        stopReadingCallback: stopReadingCallback,
      ),
      onTap: onTap,
    );
  }
}

class _QuestionPartTrailing extends StatelessWidget {
  const _QuestionPartTrailing({
    required this.question,
    required this.onNewQuestion,
    required this.viewSpan,
    required this.pageMode,
    required this.studentId,
    required this.onStateChange,
    required this.hasAction,
    required this.isAnswerShown,
    required this.isReading,
    required this.startReadingCallback,
    required this.stopReadingCallback,
  });

  final Question? question;
  final VoidCallback onNewQuestion;
  final Target viewSpan;
  final PageMode pageMode;
  final String? studentId;
  final VoidCallback onStateChange;
  final bool hasAction;
  final bool isAnswerShown;
  final bool isReading;
  final VoidCallback startReadingCallback;
  final VoidCallback stopReadingCallback;

  bool _isQuestionActive(BuildContext context) {
    final answers = Provider.of<AllAnswers>(context, listen: false)
        .filter(questionIds: [question!.id], studentIds: [studentId!]);

    if (answers.isEmpty) return question!.defaultTarget == Target.all;

    return answers.first.isActive;
  }

  @override
  Widget build(BuildContext context) {
    final userType =
        Provider.of<Database>(context, listen: false).currentUser!.userType;

    final allAnswers = question == null
        ? []
        : Provider.of<AllAnswers>(context, listen: false).filter(
            questionIds: [question!.id],
            studentIds: studentId == null ? null : [studentId!]).toList();

    if (userType == UserType.student) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TakingActionNotifier(
            number: hasAction ? 1 : null,
            forcedText: '?',
            borderColor: Colors.black,
            child: const Text(''),
          ),
          isReading
              ? IconButton(
                  onPressed: stopReadingCallback,
                  icon: const Icon(Icons.volume_off))
              : IconButton(
                  onPressed: startReadingCallback,
                  icon: const Icon(Icons.volume_up)),
        ],
      );
    } else if (userType == UserType.teacher) {
      if (question == null) {
        return _QuestionAddButton(newQuestionCallback: onNewQuestion);
      } else if (viewSpan == Target.individual && pageMode == PageMode.edit) {
        return _QuestionActivatedState(
          question: question!,
          studentId: studentId!,
          initialStatus: _isQuestionActive(context),
          onStateChange: onStateChange,
          viewSpan: viewSpan,
          pageMode: pageMode,
        );
      } else if (studentId != null && allAnswers.first.isValidated) {
        return Icon(Icons.check, size: 35, color: Colors.green[600]);
      } else {
        return const SizedBox();
      }
    } else {
      throw const NotLoggedIn();
    }
  }
}

class _QuestionAddButton extends StatelessWidget {
  const _QuestionAddButton({required this.newQuestionCallback});
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

class _QuestionActivatedState extends StatelessWidget {
  const _QuestionActivatedState({
    required this.studentId,
    required this.onStateChange,
    required this.initialStatus,
    required this.question,
    required this.viewSpan,
    required this.pageMode,
  });

  final String? studentId;
  final Question question;
  final bool initialStatus;
  final VoidCallback onStateChange;
  final Target viewSpan;
  final PageMode pageMode;

  Future<void> _toggleQuestionActiveState(BuildContext context, value) async {
    final questions = Provider.of<AllQuestions>(context, listen: false);
    final answers = Provider.of<AllAnswers>(context, listen: false);

    final sure = pageMode == PageMode.edit && viewSpan == Target.all
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

    // Modify the question on the server.
    // If the default target ever was 'all' keep it like that, unless it is
    // deactivate for all. If it was 'individual' keep it like that unless it
    // should be promoted to 'all'
    late final Target newTarget;
    if (studentId == null) {
      newTarget = value ? Target.all : Target.none;
    } else {
      newTarget = question.defaultTarget;
    }
    questions.replace(question.copyWith(defaultTarget: newTarget));

    // Modify the answers on the server
    final filteredAnswers = answers.filter(
        questionIds: [question.id],
        studentIds: studentId == null ? null : [studentId!]);
    answers.addAnswers(filteredAnswers.map((e) => e.copyWith(isActive: value)));

    onStateChange();
  }

  @override
  Widget build(BuildContext context) {
    return Switch(
        onChanged: (value) => _toggleQuestionActiveState(context, value),
        value: initialStatus);
  }
}
