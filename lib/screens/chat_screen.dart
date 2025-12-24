import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/math_text.dart';
<<<<<<< HEAD
import '../services/tts_service.dart';
import '../services/language_service.dart';
=======
>>>>>>> 5789a775d90edf4535bd98f15a65e5b44813027c

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = []; // 'role', 'content'
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();
  bool _showWelcome = true;
  String? _selectedSubject; // Null means "All Subjects"
  bool _initialized = false;
  StreamSubscription<String>? _currentStream; // Track active stream for cancellation

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final languageService = Provider.of<LanguageService>(context);
      _messages.add({
        'role': 'assistant',
        'content': languageService.translate(
            'Hello! Ask me anything about your subjects, and I\'ll find the answer in your downloaded lessons.'),
      });
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _currentStream?.cancel();
    TtsService().stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    final languageService = Provider.of<LanguageService>(context, listen: false);

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isTyping = true;
      _controller.clear();
      _showWelcome = false;
    });
    _scrollToBottom();

    final aiService = Provider.of<CourseProvider>(
      context,
      listen: false,
    ).aiService;

    String fullResponse = "";
    setState(() {
      _messages.add({'role': 'assistant', 'content': ''});
    });

    try {
      // Use streaming chat for all cases (includes fallback message if model not loaded)
<<<<<<< HEAD
      final stream = aiService
          .chat(text,
              subject: _selectedSubject)
          .timeout(const Duration(seconds: 180));
      
      _currentStream = stream.listen(
        (token) {
          setState(() {
            fullResponse += token;
            _messages.last['content'] = fullResponse;
          });
          _scrollToBottom();
        },
        onDone: () {
          setState(() {
            _isTyping = false;
            _currentStream = null;
          });
        },
        onError: (e) {
          setState(() {
            if (e is TimeoutException) {
              _messages.last['content'] =
                  "⚠️ ${languageService.translate('Response timed out. The AI model is taking too long to respond. Please try again.')}";
            } else {
              _messages.last['content'] = "Error: $e";
            }
            _isTyping = false;
            _currentStream = null;
          });
        },
        cancelOnError: true,
      );
=======
      await for (final token in aiService.chat(text, subject: _selectedSubject).timeout(const Duration(seconds: 180))) {
        setState(() {
          fullResponse += token;
          _messages.last['content'] = fullResponse;
        });
        _scrollToBottom();
      }
      setState(() {
        _isTyping = false;
      });
    } on TimeoutException catch (_) {
      setState(() {
        _messages.last['content'] = "⚠️ Response timed out. The AI model is taking too long to respond. Please try again.";
        _isTyping = false;
      });
>>>>>>> 5789a775d90edf4535bd98f15a65e5b44813027c
    } catch (e) {
      // Error already handled in stream listener
      print('Chat error: $e');
    }
    _scrollToBottom();
  }

  void _stopGeneration() {
    // Cancel the active stream
    _currentStream?.cancel();
    _currentStream = null;
    
    setState(() {
      _isTyping = false;
      // Mark the last message as stopped
      if (_messages.isNotEmpty && _messages.last['role'] == 'assistant') {
        final currentContent = _messages.last['content'] ?? '';
        _messages.last['content'] = currentContent + '\n\n_[Response stopped by user]_';
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageService = Provider.of<LanguageService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Consumer<CourseProvider>(
          builder: (context, provider, child) {
            final subjects = [
              languageService.translate('All Subjects'),
              ...provider.courses.map((c) => c.title),
            ];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade300,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSubject ?? languageService.translate('All Subjects'),
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                  isDense: true,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                  items: subjects.map((String subject) {
                    return DropdownMenuItem<String>(
                      value: subject,
                      child: Text(
                        subject,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedSubject = newValue == languageService.translate('All Subjects')
                          ? null
                          : newValue;
                    });
                  },
                ),
              ),
            );
          },
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: languageService.translate('Clear Chat & Refresh Memory'),
            onPressed: () async {
              final provider = Provider.of<CourseProvider>(
                context,
                listen: false,
              );
              await provider.aiService.clearChatSession();

              setState(() {
                _messages.clear();
                _messages.add({
                  'role': 'assistant',
                  'content':
                      languageService.translate('Chat cleared and memory refreshed! Ask me anything!'),
                });
                _showWelcome = true;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                final isWelcome = index == 0 && _showWelcome;

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: GestureDetector(
                    onDoubleTap: () {
                      if (!isUser) {
                        // Optional double tap shortcut
                      }
                    },
                    child: Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? (isDark
                                      ? AppTheme.darkCard
                                      : AppTheme.cyanSecondary)
                                : (isDark
                                      ? AppTheme.darkSurface
                                      : Colors.grey.shade200),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isUser ? 16 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MathText(
                                msg['content'] ?? '',
                                style: TextStyle(
                                  color: isUser && !isDark
                                      ? Colors.white
                                      : null,
                                  fontSize: 15,
                                ),
                              ),
                              if (!isUser &&
                                  (msg['content']?.isNotEmpty ?? false)) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: AnimatedBuilder(
                                    animation: TtsService(),
                                    builder: (context, _) {
                                      final isPlayingThisMsg =
                                          TtsService().isPlaying &&
                                          TtsService().currentText ==
                                              msg['content'];

                                      return InkWell(
                                        onTap: () {
                                          if (isPlayingThisMsg) {
                                            TtsService().stop();
                                          } else {
                                            TtsService().speak(
                                              msg['content'] ?? '',
                                            );
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Icon(
                                            isPlayingThisMsg
                                                ? Icons.stop_rounded
                                                : Icons.volume_up_rounded,
                                            size: 20,
                                            color: isPlayingThisMsg
                                                ? Colors.redAccent
                                                : AppTheme.cyanAccent,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
<<<<<<< HEAD
=======
                    child: MathText(
                      msg['content'] ?? '',
                      style: TextStyle(
                        color: isUser && !isDark ? Colors.white : null,
                        fontSize: 15,
                      ),
                    ),
>>>>>>> 5789a775d90edf4535bd98f15a65e5b44813027c
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurface
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.cyanAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          languageService.translate('AI is typing...'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: languageService.translate('Ask a question...'),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        hintStyle: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.cyanAccent, AppTheme.cyanSecondary],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: _isTyping
                      ? IconButton(
                          icon: const Icon(Icons.stop_circle_rounded),
                          color: Colors.white,
                          onPressed: _stopGeneration,
                          tooltip: 'Stop generation',
                        )
                      : IconButton(
                          icon: const Icon(Icons.send_rounded),
                          color: Colors.white,
                          onPressed: _sendMessage,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
