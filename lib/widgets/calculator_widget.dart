import 'package:flutter/material.dart';
import '../utils/translations.dart';

class CalculatorWidget extends StatefulWidget {
  const CalculatorWidget({super.key});

  @override
  State<CalculatorWidget> createState() => _CalculatorWidgetState();
}

class _CalculatorWidgetState extends State<CalculatorWidget> {
  String _expression = "";
  String _result = "0";

  void _buttonPressed(String buttonText) {
    setState(() {
      if (buttonText == "C") {
        _expression = "";
        _result = "0";
      } else if (buttonText == "⌫") {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (buttonText == "=") {
        _calculateResult();
      } else if (buttonText == "+" || buttonText == "-" || buttonText == "×" || buttonText == "÷") {
        if (_expression.isNotEmpty) {
          String lastChar = _expression.substring(_expression.length - 1);
          if (lastChar == "+" || lastChar == "-" || lastChar == "×" || lastChar == "÷") {
            // যদি শেষ ক্যারেক্টার অপারেটর হয়, তবে সেটি বদলে দিবে
            _expression = _expression.substring(0, _expression.length - 1) + buttonText;
          } else {
            _expression += buttonText;
          }
        }
      } else if (buttonText == ".") {
        // দশমিকের লজিক: একটি সংখ্যায় যেন একাধিক দশমিক না থাকে
        List<String> parts = _expression.split(RegExp(r'[+\-×÷]'));
        if (!parts.last.contains(".")) {
          _expression += buttonText;
        }
      } else {
        _expression += buttonText;
      }
    });
  }

  void _calculateResult() {
    try {
      String finalExpression = _expression.replaceAll('×', '*').replaceAll('÷', '/');
      if (finalExpression.isEmpty) return;

      // খুব সাধারণ একটি ম্যাথ পার্সার লজিক (BODMAS মেইনটেইন করার চেষ্টা করবে)
      double eval = _evaluateExpression(finalExpression);
      
      String res = eval.toString();
      if (res.endsWith(".0")) {
        res = res.substring(0, res.length - 2);
      }
      
      setState(() {
        _result = res;
        _expression = res; // ফলাফলকে আবার এক্সপ্রেশন হিসেবে সেট করা যাতে চেইন করা যায়
      });
    } catch (e) {
      setState(() {
        _result = "Error";
      });
    }
  }

  // বেসিক এক্সপ্রেশন ইভ্যালুয়েটর
  double _evaluateExpression(String expression) {
    // এই ফাংশনটি খুব সহজভাবে অপারেটরগুলো প্রসেস করবে
    // বাস্তব প্রফেশনাল অ্যাপে math_expressions লাইব্রেরি ব্যবহার করা হয়
    // এখানে আমরা ম্যানুয়ালি হ্যান্ডেল করছি যাতে কোনো নতুন ডিপেন্ডেন্সি না লাগে
    
    try {
      List<String> tokens = [];
      String number = "";
      
      for (int i = 0; i < expression.length; i++) {
        String char = expression[i];
        if ("0123456789.".contains(char)) {
          number += char;
        } else {
          if (number.isNotEmpty) tokens.add(number);
          tokens.add(char);
          number = "";
        }
      }
      if (number.isNotEmpty) tokens.add(number);

      if (tokens.isEmpty) return 0;

      // ১. গুণ ও ভাগ আগে করা (Order of Operations)
      for (int i = 0; i < tokens.length; i++) {
        if (tokens[i] == "*" || tokens[i] == "/") {
          double left = double.parse(tokens[i - 1]);
          double right = double.parse(tokens[i + 1]);
          double res = tokens[i] == "*" ? left * right : left / right;
          tokens[i - 1] = res.toString();
          tokens.removeAt(i);
          tokens.removeAt(i);
          i--;
        }
      }

      // ২. যোগ ও বিয়োগ করা
      double total = double.parse(tokens[0]);
      for (int i = 1; i < tokens.length; i += 2) {
        String op = tokens[i];
        double val = double.parse(tokens[i + 1]);
        if (op == "+") total += val;
        if (op == "-") total -= val;
      }

      return total;
    } catch (_) {
      throw Exception("Invalid");
    }
  }

  Widget _buildButton(String buttonText, {Color? color, Color? textColor, int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Colors.grey.shade200,
            foregroundColor: textColor ?? Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: () => _buttonPressed(buttonText),
          child: Text(
            buttonText,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppTranslations.currentLanguage == 'bn' ? 'ক্যালকুলেটর' : 'Calculator',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ডিসপ্লে এরিয়া
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _expression.isEmpty ? "0" : _expression,
                  style: const TextStyle(fontSize: 18, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  _result,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // বাটন গ্রিড
          Column(
            children: [
              Row(
                children: [
                  _buildButton("C", color: Colors.red.shade50, textColor: Colors.red),
                  _buildButton("⌫", color: Colors.orange.shade50, textColor: Colors.orange.shade900),
                  _buildButton("÷", color: Colors.blue.shade50, textColor: const Color(0xFF0D47A1)),
                  _buildButton("×", color: Colors.blue.shade50, textColor: const Color(0xFF0D47A1)),
                ],
              ),
              Row(
                children: [
                  _buildButton("7"),
                  _buildButton("8"),
                  _buildButton("9"),
                  _buildButton("-", color: Colors.blue.shade50, textColor: const Color(0xFF0D47A1)),
                ],
              ),
              Row(
                children: [
                  _buildButton("4"),
                  _buildButton("5"),
                  _buildButton("6"),
                  _buildButton("+", color: Colors.blue.shade50, textColor: const Color(0xFF0D47A1)),
                ],
              ),
              Row(
                children: [
                  _buildButton("1"),
                  _buildButton("2"),
                  _buildButton("3"),
                  _buildButton("=", color: const Color(0xFF0D47A1), textColor: Colors.white),
                ],
              ),
              Row(
                children: [
                  _buildButton("0", flex: 2),
                  _buildButton("."),
                  Expanded(child: Container()), // স্পেস ফিল করার জন্য
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
