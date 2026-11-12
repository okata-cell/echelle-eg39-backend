// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Action « Coller » posée dans la marge droite d'un champ de saisie.
///
/// Le raccourci ⌘V dépend du clavier matériel et du presse-papiers du système :
/// dans le simulateur iOS il n'aboutit pas toujours, alors que le collage par
/// menu, lui, fonctionne. Cette action donne donc un chemin de collage qui ne
/// dépend que de l'application.
///
/// Elle disparaît d'elle-même quand le presse-papiers est vide et, par défaut,
/// dès que le champ contient déjà du texte : la place revient alors à l'action
/// de l'écran (effacer, afficher le mot de passe).
class ClipboardPasteAction extends StatefulWidget {
  const ClipboardPasteAction({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hideWhenFilled = true,
    this.trim = true,
    this.iconColor = const Color(0xFF7A7A7A),
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Masque l'action dès que le champ contient du texte.
  final bool hideWhenFilled;

  /// Retire les espaces et retours à la ligne autour du texte collé.
  final bool trim;

  final Color iconColor;

  @override
  State<ClipboardPasteAction> createState() => _ClipboardPasteActionState();
}

class _ClipboardPasteActionState extends State<ClipboardPasteAction>
    with WidgetsBindingObserver {
  bool _pressePapiersRempli = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_rafraichir);
    // Un collage se prépare souvent ailleurs : on revérifie à chaque prise de
    // focus, pas seulement à l'ouverture de l'écran.
    widget.focusNode.addListener(_rafraichir);
    _rafraichir();
  }

  @override
  void didUpdateWidget(ClipboardPasteAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rafraichir);
      widget.controller.addListener(_rafraichir);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_rafraichir);
      widget.focusNode.addListener(_rafraichir);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_rafraichir);
    widget.focusNode.removeListener(_rafraichir);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On copie souvent depuis une autre application : au retour, le presse-papiers
    // a changé et l'action doit apparaître sans quitter le champ.
    if (state == AppLifecycleState.resumed) _rafraichir();
  }

  void _rafraichir() {
    _lirePressePapiers();
    if (mounted) setState(() {});
  }

  Future<void> _lirePressePapiers() async {
    bool rempli;
    try {
      rempli = await Clipboard.hasStrings();
    } catch (_) {
      // Plateforme sans presse-papiers interrogeable : on n'affiche rien.
      rempli = false;
    }

    if (!mounted || rempli == _pressePapiersRempli) return;
    setState(() => _pressePapiersRempli = rempli);
  }

  Future<void> _coller() async {
    String? texte;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      texte = data?.text;
    } catch (_) {
      texte = null;
    }

    if (!mounted) return;

    final valeur = widget.trim ? (texte ?? '').trim() : (texte ?? '');
    if (valeur.isEmpty) {
      setState(() => _pressePapiersRempli = false);
      return;
    }

    widget.controller.value = TextEditingValue(
      text: valeur,
      selection: TextSelection.collapsed(offset: valeur.length),
    );
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final champRempli = widget.controller.text.isNotEmpty;
    if (!_pressePapiersRempli || (widget.hideWhenFilled && champRempli)) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: 'Coller',
      onPressed: _coller,
      icon: Icon(
        Icons.content_paste_rounded,
        size: 20,
        color: widget.iconColor,
      ),
    );
  }
}
