import { Injectable, Logger } from '@nestjs/common';

export abstract class SmsProvider {
  abstract send(phone: string, text: string): Promise<void>;
}

/** Development SMS provider: prints the message to the log instead of sending it. */
@Injectable()
export class ConsoleSmsProvider extends SmsProvider {
  private readonly log = new Logger('SMS');
  readonly outbox: { phone: string; text: string }[] = [];

  async send(phone: string, text: string): Promise<void> {
    this.outbox.push({ phone, text });
    this.log.log(`to ${phone}: ${text}`);
  }
}
