import 'package:flutter/material.dart';

class MyCustomController extends TextEditingController {
  String? textoLockup;
  int? valorLockup = 0;
  bool estado = false;
  bool estadoinicial = false;
  int _selecionado = 0;
  int? valorviejo = 0;
  bool _mostrar = false;

  MyCustomController() {
    estadoinicial = true; // Asegura que el estado inicial sea true
  }

  bool getmostrar() {
    return _mostrar;
  }

  int? getvalor() {
    return valorLockup;
  }

  int? getvalorviejo() {
    return valorviejo;
  }

  bool? getEstado() {
    return estado;
  }

  bool getEstadoinicial() {
    return estadoinicial;
  }

  mostrar() {
    _mostrar = true;
    notifyListeners();
  }

  nomostrar() {
    _mostrar = false;
    notifyListeners();
  }

  SetSeleccionadoOk() {
    _selecionado = 1;
    estadoinicial = false;
  }

  SetSeleccionadoNoestaOk() {
    _selecionado = 2;
    estadoinicial = false;
  }

  SetSeleccionadoClear() {
    _selecionado = 4;
    estadoinicial = false;
  }

  int? getseleccionado() {
    return _selecionado;
  }

  SetValor(int? pv) {
    valorviejo = valorLockup;
    valorLockup = pv;
  }

  SetValorEstdoInicial() {
    print('SetValorEstdoInicial');
    estadoinicial = true;
  }

  SetValorEstadoOk() {
    estado = true;
  }

  SetValorEstadoNoOk() {
    estado = false;
  }
}
