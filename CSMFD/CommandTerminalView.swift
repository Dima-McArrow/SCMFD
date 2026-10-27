import SwiftUI

struct CommandTerminalView: View {
    let session: DemoSession
    let horizontal: Bool
    @Environment(\.manufacturerTheme) private var manufacturerTheme
    private var theme: MFDTheme { MFDTheme(manufacturerTheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MFDPageHeading(
                eyebrow: "UTILITY CONSOLE / COMMAND LINK / MFD–03",
                title: "Полевой терминал",
                subtitle: "Контекст из лога и отдельный канал команд. Сейчас оба работают в демо-режиме.",
                theme: theme
            )

            MFDPanel(theme: theme, highlighted: true) {
                MFDLabel(text: "ПОСЛЕДНЯЯ ЗАМЕЧЕННАЯ ЛОКАЦИЯ", theme: theme)
                Text("HDPC-Farnesway")
                    .font(.system(.largeTitle, design: .monospaced).weight(.medium))
                    .foregroundStyle(theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
                Label("21:48:04 UTC · запрос инвентаря", systemImage: "clock")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(theme.muted)
                Text("Это точка наблюдения. Текущее положение и дальнейшее перемещение неизвестны.")
                    .font(.callout)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            MFDColumns(horizontal: horizontal) {
                VStack(alignment: .leading, spacing: 12) {
                    MFDLabel(text: "ВЫВОД КОМАНД / ЛОКАЛЬНАЯ ИМИТАЦИЯ", theme: theme)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        ForEach(ShipCommand.allCases) { command in
                            Button {
                                session.sendDemoCommand(command)
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    Image(systemName: command.symbol)
                                        .font(.title2)
                                        .accessibilityHidden(true)
                                    Text(command.title)
                                    Text(command.code)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(theme.muted)
                                }
                                .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                            }
                            .buttonStyle(MFDButtonStyle(theme: theme))
                            .accessibilityHint(
                                "Создаёт только локальную демо-квитанцию. Команда не отправляется в игру."
                            )
                            .accessibilityIdentifier("terminal.\(command.rawValue)")
                        }
                    }
                }
            } trailing: {
                MFDPanel(theme: theme) {
                    MFDLabel(text: "КВИТАНЦИИ / ПОСЛЕДНИЕ 6", theme: theme)
                    if session.receipts.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Image(systemName: "terminal")
                                .font(.largeTitle)
                                .foregroundStyle(theme.accent)
                                .accessibilityHidden(true)
                            Text("Ожидание команды")
                                .font(.system(.headline, design: .monospaced))
                            Text("Нажми кнопку слева. Панель покажет получение команды демо-сервисом.")
                                .font(.callout)
                                .foregroundStyle(theme.muted)
                        }
                        .padding(.vertical, 12)
                    } else {
                        ForEach(session.receipts) { receipt in
                            VStack(alignment: .leading, spacing: 7) {
                                MFDLabel(text: "ДЕМО / ACK–\(receipt.id)", theme: theme)
                                Text(receipt.command.title)
                                    .font(.system(.callout, design: .monospaced).weight(.medium))
                                Text("Получена имитатором. Результат в игре неизвестен.")
                                    .font(.caption)
                                    .foregroundStyle(theme.muted)
                                Rectangle().fill(theme.edge).frame(height: 1)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .accessibilityIdentifier("terminal.receipts")
            }

            MFDReceipt(
                title: "КАНАЛ СОСТОЯНИЯ / НЕТ ИСТОЧНИКА",
                message:
                    "Щиты — нет данных. Топливо — нет данных. Положение шасси — неизвестно. Отправка команды эти значения не подтверждает.",
                theme: theme
            )

            MFDSourceNote(
                theme: theme,
                lines: [
                    "Образец: 19.06.2026 · SC Tracker / sample-events.log.",
                    "Наблюдение инвентаря относится к Farnesway в 21:48:04 UTC.",
                    "Location: Stanton1_DistributionCentre_Hurston_Farnesway.",
                    "Кнопки работают только с локальным имитатором: сетевого соединения и эмуляции клавиш пока нет.",
                    "Подтверждение получения команды и подтверждение состояния игры — разные события.",
                ])
        }
    }
}

#Preview("Terminal / Ожидание", traits: .fixedLayout(width: 1194, height: 834)) {
    MFDPreviewSurface(page: .terminal)
}

#Preview("Terminal / Квитанции", traits: .fixedLayout(width: 1194, height: 834)) {
    MFDPreviewSurface(page: .terminal, scenario: .withReceipts)
}
