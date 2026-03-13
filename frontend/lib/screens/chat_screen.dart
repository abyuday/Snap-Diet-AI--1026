import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/user_provider.dart';
import '../services/history_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initial greeting
    _messages.add(ChatMessage(
      text: "Namaste! I'm your AI Dietitian. How can I help you meet your nutritional goals today?",
      isAi: true,
    ));
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    if (_controller.text.trim().isEmpty || _isLoading) return;

    final userMsg = _controller.text.trim();
    setState(() {
      _messages.add(ChatMessage(text: userMsg, isAi: false));
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final historyProvider = Provider.of<HistoryProvider>(context, listen: false);

      final response = await apiService.sendChatMessage(
        message: userMsg,
        profile: {
          'name': userProvider.name,
          'rank': userProvider.rank,
        },
        history: historyProvider.history.map((e) => {
          'calories': e.calories,
          'protein': e.protein,
          'name': e.foodName
        }).toList(),
        goals: {
          'daily_calories': userProvider.calorieGoal,
          'protein_target': userProvider.proteinGoal,
        },
      );

      setState(() {
        _messages.add(ChatMessage(
          text: response['reply'], 
          isAi: true,
          suggestions: response['recommendations']
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "I'm having trouble connecting to my brain right now. Please check your internet or try again later!",
          isAi: true,
        ));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length,
                itemBuilder: (context, index) => _messages[index],
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
              ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "AI Dietitian",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Expert Indian Nutritionist",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _handleSend(),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Ask about your goals...",
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isAi;
  final List<dynamic>? suggestions;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isAi,
    this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isAi ? AppTheme.surfaceColor : AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isAi ? 0 : 20),
                bottomRight: Radius.circular(isAi ? 20 : 0),
              ),
              border: Border.all(
                color: isAi ? Colors.white.withOpacity(0.05) : AppTheme.primaryColor.withOpacity(0.5)
              ),
            ),
            child: isAi 
                ? MarkdownBody(
                    data: text,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 15, height: 1.5),
                      listBullet: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 15),
                      strong: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  )
                : Text(
                    text,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
          ),
          if (suggestions != null && suggestions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions!.length,
                itemBuilder: (context, idx) {
                  final rec = suggestions![idx];
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Text(rec['emoji'] ?? "🍲", style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                rec['name'],
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                rec['reason'],
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          ]
        ],
      ),
    );
  }
}
