/**
 * First-pass text screening for prompts and messages (section 5): phone numbers, payment
 * solicitation and obvious abuse. A hosted classifier replaces the word list later.
 */
const PHONE = /(?:\+?\d[\s\-.()]*){10,}/;
const PAYMENT = /\b(upi|paytm|gpay|google pay|phonepe|bank transfer|send (me )?money|western union|crypto|bitcoin|usdt|gift ?card)\b/i;
const ABUSE = /\b(kill you|rape|whore|slut|randi)\b/i;

export type ScreenFlag = 'phone_number' | 'payment' | 'abuse';

export function screenText(text: string): ScreenFlag[] {
  const flags: ScreenFlag[] = [];
  if (PHONE.test(text)) flags.push('phone_number');
  if (PAYMENT.test(text)) flags.push('payment');
  if (ABUSE.test(text)) flags.push('abuse');
  return flags;
}
