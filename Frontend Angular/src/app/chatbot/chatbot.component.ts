import { Component, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { environment } from 'src/environments/environment';

interface CustomQA {
  question: string;
  answer: string;
}

@Component({
  selector: 'app-chatbot',
  templateUrl: './chatbot.component.html',
  styleUrls: ['./chatbot.component.css']

})
export class ChatbotComponent implements OnInit {
  userInput = '';
  messages: { role: string, text: string }[] = [];
  customData: CustomQA[] = [];

  constructor(private http: HttpClient) {}

  ngOnInit() {
    this.http.get<CustomQA[]>('assets/mydata.json').subscribe(data => {
      this.customData = data;
    });
  }

  sendMessage() {
    const input = this.userInput.trim();
    if (!input) return;

    this.messages.push({ role: 'user', text: input });
    this.userInput = '';

    const match = this.findClosestMatch(input, this.customData);

    if (match) {
      this.messages.push({ role: 'assistant', text: match.answer });
      return;
    }
    const suggestions = this.customData.filter(q =>
      input.toLowerCase().split(' ').some(word =>
        q.question.toLowerCase().includes(word)
      )
    );

    if (suggestions.length > 0) {
      this.messages.push({
        role: 'assistant',
        text: `Je n'ai pas trouvé de réponse exacte, mais avez-vous voulu dire :\n- ${suggestions
          .map(q => q.question)
          .join('\n- ')}`
      });
      return;
    }

    // Sinon appel à l'IA Gemini
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${environment.GEMINI_API_KEY}`;
    const body = {
      contents: [{ parts: [{ text: input }] }]
    };

    this.http.post<any>(url, body).subscribe({
      next: res => {
        const reply = res.candidates[0].content.parts[0].text;
        this.messages.push({ role: 'assistant', text: reply });
      },
      error: err => {
        this.messages.push({ role: 'assistant', text: 'Erreur avec l’IA.' });
        console.error(err);
      }
    });
  }

  private findClosestMatch(input: string, data: CustomQA[]): CustomQA | undefined {
    const inputLower = input.toLowerCase();

    let bestMatch: CustomQA | undefined;
    let highestScore = 0;

    for (const item of data) {
      const questionLower = item.question.toLowerCase();
      let score = 0;

      if (questionLower.includes(inputLower)) {
        score += 5;
      }

      const words = inputLower.split(' ');
      for (const word of words) {
        if (questionLower.includes(word)) {
          score += 1;
        }
      }

      if (score > highestScore) {
        highestScore = score;
        bestMatch = item;
      }
    }

    return highestScore >= 3 ? bestMatch : undefined; // Seuil de pertinence
  }
}
