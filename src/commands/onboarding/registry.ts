import type { ChannelChoice } from "../onboard-types.js";
import type { ChannelOnboardingAdapter } from "./types.js";
import { listChannelPlugins } from "../../channels/plugins/index.js";
import { discordOnboardingAdapter } from "../../channels/plugins/onboarding/discord.js";
import { imessageOnboardingAdapter } from "../../channels/plugins/onboarding/imessage.js";
import { signalOnboardingAdapter } from "../../channels/plugins/onboarding/signal.js";
import { slackOnboardingAdapter } from "../../channels/plugins/onboarding/slack.js";
import { telegramOnboardingAdapter } from "../../channels/plugins/onboarding/telegram.js";
import { whatsappOnboardingAdapter } from "../../channels/plugins/onboarding/whatsapp.js";

const BUILTIN_CHANNEL_ONBOARDING_ADAPTERS: ReadonlyArray<
  readonly [ChannelChoice, ChannelOnboardingAdapter]
> = [
  ["telegram", telegramOnboardingAdapter],
  ["whatsapp", whatsappOnboardingAdapter],
  ["discord", discordOnboardingAdapter],
  ["slack", slackOnboardingAdapter],
  ["signal", signalOnboardingAdapter],
  ["imessage", imessageOnboardingAdapter],
];

const CHANNEL_ONBOARDING_ADAPTERS = () =>
  new Map<ChannelChoice, ChannelOnboardingAdapter>([
    ...BUILTIN_CHANNEL_ONBOARDING_ADAPTERS,
    ...listChannelPlugins()
      .map((plugin) => (plugin.onboarding ? ([plugin.id, plugin.onboarding] as const) : null))
      .filter((entry): entry is readonly [ChannelChoice, ChannelOnboardingAdapter] =>
        Boolean(entry),
      ),
  ]);

export function getChannelOnboardingAdapter(
  channel: ChannelChoice,
): ChannelOnboardingAdapter | undefined {
  return CHANNEL_ONBOARDING_ADAPTERS().get(channel);
}

export function listChannelOnboardingAdapters(): ChannelOnboardingAdapter[] {
  return Array.from(CHANNEL_ONBOARDING_ADAPTERS().values());
}

// Legacy aliases (pre-rename).
export const getProviderOnboardingAdapter = getChannelOnboardingAdapter;
export const listProviderOnboardingAdapters = listChannelOnboardingAdapters;
