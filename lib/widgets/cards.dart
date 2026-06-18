import 'package:flutter/material.dart';
import '../constants.dart';

Widget categoryButton(IconData icon, String title, VoidCallback onTap) {
  return InkWell(
    borderRadius: BorderRadius.circular(22),
    onTap: onTap,
    child: category(icon, title),
  );
}

Widget category(IconData icon, String title) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: green, size: 34),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

Widget latest(String title, String city) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Icon(Icons.article, color: green),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Text(city, style: const TextStyle(color: Colors.grey)),
      ],
    ),
  );
}