# NetPulse

App em Flutter para escanear portas TCP e descobrir dispositivos ativos na rede local.

## Funcionalidades

- **Scanner de Portas** — testa a conexão em portas TCP de um IP alvo (lista customizável, aceita portas soltas e faixas, ex: `22,80,443,8000-8010`), em paralelo e com progresso visível.
- **Dispositivos na Rede** — detecta o IP e a sub-rede reais do próprio aparelho e varre a rede local em busca de hosts que respondem de verdade (nenhum resultado é simulado).
- **Meu IP** — o app detecta o IP local do dispositivo (WiFi ou qualquer interface de rede) e permite reutilizá-lo com um toque.
- Suporte a Android, iOS, Windows, macOS e Linux, com layout adaptado para telas largas.

## Uso responsável

Este app só deve ser usado em redes e equipamentos que você tem autorização para testar. Escanear redes de terceiros sem permissão pode violar leis locais.

## Rodando o projeto

```bash
flutter pub get
flutter run
```

Testes:

```bash
flutter test
```

Ícones de app para iOS/macOS/Windows/Linux (Android e Web já estão prontos em `android/app/src/main/res` e `web/icons`):

```bash
dart run flutter_launcher_icons
```

## Estrutura

- `lib/screens/` — telas (Scanner de Portas, Dispositivos na Rede)
- `lib/services/` — lógica de scan de portas/rede, detecção de IP local e histórico de varreduras
- `test/` — testes de widget e dos serviços
