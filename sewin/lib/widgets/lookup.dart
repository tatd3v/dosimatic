import 'package:sewin/utils/my_custom_controller.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/lookup_service.dart';

// Data model class for generic lookup data
class DatosGenerico {
  final int id;
  final String? nombre;

  DatosGenerico({required this.id, this.nombre});

  @override
  String toString() => nombre ?? '';
}

class lookupPage extends StatefulWidget {
  final String urllokup;
  final String etiqueta;
  final VoidCallback onCountSelected;
  final Function(String, String, String) onItemSelected;
  const lookupPage(
      {Key? key,
      required this.onCountSelected,
      required this.onItemSelected,
      required this.urllokup,
      required this.etiqueta})
      : super(key: key);
  @override
  EmpleadoPageState createState() => EmpleadoPageState();
}

class EmpleadoPageState extends State<lookupPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List data = [];
  List datafiltrada = [];
  final _myinvoice = <String>{};
  List<String> dataVenta = [];
  TextEditingController editingController = TextEditingController();
  String mywebserver = "vacio";
  bool _isSearching = false;

  Future<String> getData() async {
    try {
      // Extract endpoint from the URL for backward compatibility
      final String endpoint =
          LookupService.extractEndpointFromUrl(widget.urllokup);

      // Load initial data using the service
      final List<Map<String, dynamic>> result =
          await LookupService.performLookup(
        endpoint: endpoint,
        searchTerm: '0',
      );

      setState(() {
        data = result;
        datafiltrada = data;
      });
      return "Success!";
    } catch (e) {
      print('Error in getData: $e');
      return "no Success*";
    }
  }

  @override
  void initState() {
    super.initState();
    getData();
    print('Estado Inicial:');
  }

  Future<void> filterSearchResults(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      // Extract endpoint from the URL for backward compatibility
      final String endpoint =
          LookupService.extractEndpointFromUrl(widget.urllokup);

      // Perform search using the service
      final List<Map<String, dynamic>> result =
          await LookupService.performLookup(
        endpoint: endpoint,
        searchTerm: query,
      );

      setState(() {
        data = result;
        _isSearching = false;
      });
    } catch (e) {
      print('Error in filterSearchResults: $e');
      // Fallback to local filtering if API fails
      _filterLocalResults(query);
      setState(() {
        _isSearching = false;
      });
    }
  }

  // Fallback local filtering method
  void _filterLocalResults(String query) {
    List dummySearchList = [];
    dummySearchList.addAll(datafiltrada);
    if (query.isNotEmpty) {
      List dummyListData = [];
      for (var item in dummySearchList) {
        if (item["datonombre"].toString().toLowerCase().contains(query)) {
          dummyListData.add(item);
        }
      }
      setState(() {
        data.clear();
        data.addAll(dummyListData);
      });
    } else {
      setState(() {
        data.clear();
        data.addAll(datafiltrada);
      });
    }
  }

// Cuadro de Dialogo.

//
  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // Add lines from here...
        builder: (BuildContext context) {
          final tiles = _myinvoice.map(
            (String pair) {
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.10,
                child: ListTile(
                  title: Text(
                    pair.toString(),
                    //style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              );
            },
          );
          final divided = ListTile.divideTiles(
            context: context,
            tiles: tiles,
          ).toList();

          return Scaffold(
            appBar: AppBar(
              title: const Text('Selector'),
            ),
            body: ListView(children: divided),
          );
        }, // ...to here.
      ),
    );
  }

//
  @override
  Widget build(BuildContext context) {
    //
    return Container(
        child: Column(children: <Widget>[
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          style: TextStyle(),
          controller: editingController,
          onSubmitted: (value) async {
            // Trigger search when Enter is pressed
            if (value.isNotEmpty) {
              await filterSearchResults(value);
            }
          },
          decoration: InputDecoration(
              labelText: "Buscar",
              hintText: "Buscar",
              prefixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      onPressed: () async {
                        // Trigger search when search icon is pressed
                        if (editingController.text.isNotEmpty) {
                          await filterSearchResults(editingController.text);
                        }
                      },
                      icon: const Icon(Icons.search),
                    ),
              suffixIcon: IconButton(
                onPressed: () {
                  editingController.clear();
                  getData();
                },
                icon: const Icon(Icons.clear),
              ),
              border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(25.0)))),
        ),
      ),
      Expanded(
          child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: data == null ? 0 : data.length,
              itemBuilder: (BuildContext context, int index) {
                if (index.isOdd) const Divider();

                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        data[index]["datonombre"].toString(),
                        textScaler: TextScaler.linear(
                            MediaQuery.textScalerOf(context).scale(1.0) * 0.9),
                      ),
                      onTap: () async {
                        print('seleciono: ' + data[index]["iddato"].toString());
                        // widget.onCountSelected(); // Commented out to prevent unwanted side effects
                        widget.onItemSelected(
                            data[index]["iddato"].toString(),
                            data[index]["iddato"].toString(),
                            data[index]["datonombre"]);
                        setState(() {});
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(),
                  ],
                );
              }))
    ]));
  }
}

class MensajeRespuesta {
  final String estado;
  final String msg;

  MensajeRespuesta(this.estado, this.msg);

  MensajeRespuesta.fromJson(Map<String, dynamic> json)
      : estado = json['estado'],
        msg = json['msg'];

  Map<String, dynamic> toJson() => {
        'estado': estado,
        'msg': msg,
      };
}
////////

class mylookup23 extends StatefulWidget {
  final String? etiqueta;
  final String? urllink;
  final MyCustomController dataController;
  final String? dato1;
  final String? dato2;

  final Function(int p) callBackDependiente;
  final Function(DatosGenerico)? funOnChange;
  final Function(String)? validador;

  const mylookup23(
      {Key? key,
      this.etiqueta,
      required this.urllink,
      required this.dataController,
      required this.callBackDependiente,
      this.validador,
      this.funOnChange,
      this.dato1,
      this.dato2})
      : super(key: key);

  @override
  State<mylookup23> createState() => _HomePageState23();
  void reset() {}
}

class _HomePageState23 extends State<mylookup23> {
  List data = [];
  List datafiltrada = [];
  final List<DatosGenerico> _datos = [];
  List<DatosGenerico> _datosdgfiltrada = [];
  DatosGenerico? _datoSeleccionado;

  Future<String> getData() async {
    try {
      var response = await http.get(Uri.parse(widget.urllink.toString()),
          headers: {"Accept": "application/json"});

      setState(() {
        data = json.decode(response.body);
        _datoSeleccionado = null;

        _suggestions.clear();
        for (int i = 0; i < data.length; i++) {
          _datos.add(DatosGenerico(
              id: data[i][widget.dato1], nombre: data[i][widget.dato2]));
          _suggestions.add(data[i][widget.dato2].toString());
        }

        try {
          _datoSeleccionado = _datos.firstWhere(
              (objeto) => objeto.id == int.parse(widget.dataController.text));

          widget.callBackDependiente(_datoSeleccionado!.id);
        } catch (e) {
          _datoSeleccionado = null;
        }
      });
      return "Success!";
    } catch (e) {
      print(e.toString());
      return "no Success*";
    }
  }

  bool _showLayoutBuilder = false;
  final List<String> _suggestions = [];
  TextEditingController mytextEditingController = TextEditingController();
  TextEditingController? autoCompleteEditingController;
  TextEditingController? autoCompleteEditingController2 =
      TextEditingController();
  FocusNode unitCodeCtrlFocusNode = FocusNode();
  ScrollController my = ScrollController();
  String textoetiqueta = '';

  @override
  void initState() {
    getData();
    textoetiqueta = 'Buscar ' + widget.etiqueta.toString();
    super.initState();
    widget.dataController.addListener(() {
      _handleTextChanges();
    });
  }

  @override
  void dispose() {
    widget.dataController.removeListener(
        _handleTextChanges); // Eliminar listener al destruir el widget
    super.dispose();
  }

  void _handleTextChanges() {
    print('Secuencia de  _handleTextChanges.');
    print('_handleTextChanges Process:' +
        widget.dataController.getseleccionado().toString());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
            builder: (_, BoxConstraints constraints) => Autocomplete<String>(
                    fieldViewBuilder: (BuildContext context,
                        TextEditingController textEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted) {
                  autoCompleteEditingController = textEditingController;
                  unitCodeCtrlFocusNode = focusNode;
                  return TextFormField(
                    autovalidateMode: AutovalidateMode
                        .onUserInteraction, // Permite validar mientras se interactúa
                    onChanged: (value) {
                      if (widget.dataController.getEstado() == false) {
                        setState(() {
                          textoetiqueta =
                              'Por favor ingrese un Valor Correcto'; // Reemplazar la etiqueta por el mensaje de error
                        });
                      } else {
                        setState(() {
                          textoetiqueta = 'Buscar ' +
                              widget.etiqueta
                                  .toString(); // Restaurar la etiqueta original si no hay error
                        });
                      }
                    },
                    readOnly: widget.dataController.estado,
                    validator: (value) {
                      if (widget.dataController.getEstado() == false) {
                        widget.dataController.SetSeleccionadoNoestaOk();
                        return 'Por favor ingrese un Valor Correcto';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      isDense: true,
                      filled: true,
                      border: const OutlineInputBorder(),
                      labelText: widget.etiqueta,
                      hintText: textoetiqueta,
                      prefixIcon: IconButton(
                          splashRadius: 0.4,
                          icon: widget.dataController.estado
                              ? Icon(Icons.check, color: Colors.blue)
                              : Icon(Icons.search, color: Colors.blue),
                          onPressed: () {
                            if (widget.dataController.getEstado() == false) {
                              autoCompleteEditingController!.text = '*';
                              FocusScope.of(context)
                                  .requestFocus(unitCodeCtrlFocusNode);
                            }
                          }),
                      suffixIcon: IconButton(
                          splashRadius: 0.5,
                          icon: const Icon(Icons.clear, color: Colors.blue),
                          onPressed: () {
                            print('//////////// Boton de Clear');
                            widget.dataController.SetSeleccionadoClear();
                            widget.dataController.SetValorEstdoInicial();
                            widget.callBackDependiente(0);
                            widget.dataController.text = 'clear';
                            autoCompleteEditingController!.clear();
                            widget.dataController.SetValorEstadoNoOk();

                            FocusScope.of(context)
                                .requestFocus(unitCodeCtrlFocusNode);
                            setState(() {
                              _showLayoutBuilder = !_showLayoutBuilder;
                            });
                          }),
                    ),
                    controller: textEditingController,
                    focusNode: focusNode,
                    onFieldSubmitted: (value) {
                      //Busca el Campo Digitado en el array y lo asigna.;

                      _datosdgfiltrada = _datos
                          .where((element) =>
                              element.id.toString() == value.toString())
                          .toList();

                      if (_datosdgfiltrada.length != 0) {
                        print('Aqui se selecciono un valor de lista Tamos ok');
                        setState(() {
                          autoCompleteEditingController!.text =
                              _datosdgfiltrada[0].nombre.toString();
                          widget.dataController.text =
                              _datosdgfiltrada[0].nombre.toString();
                          widget.dataController
                              .SetValor(_datosdgfiltrada[0].id);
                          widget.dataController.SetValorEstadoOk();
                          widget.dataController.SetSeleccionadoOk();
                        });
                      } else {
                        setState(() {
                          widget.dataController.SetSeleccionadoNoestaOk();
                          autoCompleteEditingController!.text = "";
                          widget.dataController.SetValorEstadoNoOk();
                          print('---Tamos Mal ***');
                        });
                      }

                      if (value.contains('\t')) {
                        print('tiene tab:' + value);
                      }
                      if (value.contains('\n')) {
                        print('tiene enter:' + value);
                      }
                      onFieldSubmitted();
                    },
                  );
                }, optionsViewBuilder: (context, onselected, _datafiltro) {
                  return SizedBox(
                    height: 200,
                    width: 300,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: Theme.of(context)
                            .dialogBackgroundColor, // Usar el color de fondo del tema

                        child: SizedBox(
                          //altura del espacio del lokup.
                          height: MediaQuery.of(context).size.height * 0.45,
                          width: constraints.maxWidth,
                          child: ListView.separated(
                            controller: my,
                            separatorBuilder:
                                (BuildContext context, int index) => Divider(
                              thickness: 0.5,
                              height: 0.5,
                            ),
                            itemCount: _datafiltro.length,
                            itemBuilder: (BuildContext context, int index2) {
                              return Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.048,
                                child: ListTile(
                                  title: Text(
                                    _datafiltro.elementAt(index2),
                                    style: TextStyle(
                                        color: Colors.blue, fontSize: 12),
                                  ),
                                  onTap: () {
                                    widget.callBackDependiente;
                                    widget.funOnChange;
                                    onselected(_datafiltro.elementAt(index2));
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                }, optionsBuilder: (TextEditingValue value) {
                  print('busqueda 4:' + value.text.toString());

                  if (autoCompleteEditingController!.text == '*') {
                    return _suggestions.toList();
                  }

                  if (value.text.isEmpty) {
                    return [];
                  }
                  print('---en datos generico');
                  _datosdgfiltrada = _datos
                      .where((element) => element.nombre!
                          .toLowerCase()
                          .contains(value.text.toLowerCase().toString()))
                      .toList();

                  for (int i = 0; i < _datosdgfiltrada.length; i++) {
                    print(_datosdgfiltrada[i].nombre);
                  }

                  return _suggestions.where((suggestion) => suggestion
                      .toLowerCase()
                      .contains(value.text.toLowerCase()));
                }, onSelected: (value) {
                  print('/onSelected/' + value);
                  _datosdgfiltrada = _datos
                      .where((element) =>
                          element.nombre!.toLowerCase() ==
                          value.toString().toLowerCase().toString())
                      .toList();
                  if (_datosdgfiltrada.length != 0) {
                    widget.dataController.SetValorEstadoOk();
                    widget.dataController.text =
                        _datosdgfiltrada[0].nombre.toString();
                    widget.dataController.SetValor(_datosdgfiltrada[0].id);
                    print('/onSelected encuentra:/' +
                        _datosdgfiltrada[0].id.toString());
                    widget.dataController.SetValorEstadoOk();
                    widget.callBackDependiente(_datosdgfiltrada[0].id);
                    if (widget.funOnChange != null) {
                      widget.funOnChange!(_datosdgfiltrada[0]);
                    }
                  } else {
                    widget.dataController.SetValorEstadoNoOk();
                  }
                })),
        const SizedBox(
          height: 10,
        ),
      ],
    );
  }
}

//reservado para valor fijos.

/*DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: "Sucursal"),
                items: <String>['Casa Matriz', 'Suc. Hatillo', 'Suc. La Exposición','Suc.Calidonia']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  // Aquí manejas el cambio de sucursal
                },
              ),*/
class mylookup33 extends StatefulWidget {
  final String? etiqueta;
  final String? urllink;
  final MyCustomController dataController;
  final String? dato1;
  final String? dato2;

  final Function(int p) callBackDependiente;
  final Function(DatosGenerico)? funOnChange;
  final Function(String)? validador;

  const mylookup33(
      {Key? key,
      this.etiqueta,
      required this.urllink,
      required this.dataController,
      required this.callBackDependiente,
      this.validador,
      this.funOnChange,
      this.dato1,
      this.dato2})
      : super(key: key);

  @override
  State<mylookup33> createState() => _HomePageState33();
  void reset() {}
}

class _HomePageState33 extends State<mylookup33> {
  List data = [];
  List datafiltrada = [];
  final List<DatosGenerico> _datos = [];
  List<DatosGenerico> _datosdgfiltrada = [];
  DatosGenerico? _datoSeleccionado;

  Future<String> getData() async {
    try {
      var response = await http.get(Uri.parse(widget.urllink.toString()),
          headers: {"Accept": "application/json"});

      setState(() {
        data = json.decode(response.body);
        _datoSeleccionado = null;

        _suggestions.clear();
        for (int i = 0; i < data.length; i++) {
          _datos.add(DatosGenerico(
              id: data[i][widget.dato1], nombre: data[i][widget.dato2]));
          _suggestions.add(data[i][widget.dato2].toString());
        }

        // Mejorar la inicialización
        try {
          if (widget.dataController.valorLockup != null &&
              widget.dataController.valorLockup != 0) {
            _datoSeleccionado = _datos.firstWhere(
                (objeto) => objeto.id == widget.dataController.valorLockup);

            // Actualizar la UI con el nombre del elemento seleccionado
            widget.dataController.text = _datoSeleccionado!.nombre!;
            widget.dataController.SetValorEstadoOk();
            widget.dataController.SetSeleccionadoOk();

            // Actualizar el campo de texto visual después de que se construya
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (autoCompleteEditingController != null) {
                autoCompleteEditingController!.text =
                    _datoSeleccionado!.nombre!;
              }
            });

            widget.callBackDependiente(_datoSeleccionado!.id);
          }
        } catch (e) {
          _datoSeleccionado = null;
          widget.dataController.SetValorEstadoNoOk();
        }
      });
      return "Success!";
    } catch (e) {
      print(e.toString());
      return "no Success*";
    }
  }

  bool _showLayoutBuilder = false;
  final List<String> _suggestions = [];
  TextEditingController mytextEditingController = TextEditingController();
  TextEditingController? autoCompleteEditingController;
  TextEditingController? autoCompleteEditingController2 =
      TextEditingController();
  FocusNode unitCodeCtrlFocusNode = FocusNode();
  ScrollController my = ScrollController();
  String textoetiqueta = '';

  @override
  void initState() {
    getData();
    textoetiqueta = 'Buscar ' + widget.etiqueta.toString();
    super.initState();
    widget.dataController.addListener(() {
      _handleTextChanges();
    });
  }

  @override
  void dispose() {
    widget.dataController.removeListener(
        _handleTextChanges); // Eliminar listener al destruir el widget
    super.dispose();
  }

  void _handleTextChanges() {
    print('Secuencia de  _handleTextChanges.');
    print('_handleTextChanges Process:' +
        widget.dataController.getseleccionado().toString());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
            builder: (_, BoxConstraints constraints) => Autocomplete<String>(
                    fieldViewBuilder: (BuildContext context,
                        TextEditingController textEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted) {
                  autoCompleteEditingController = textEditingController;
                  unitCodeCtrlFocusNode = focusNode;
                  return TextFormField(
                    autovalidateMode: AutovalidateMode
                        .onUserInteraction, // Permite validar mientras se interactúa
                    onChanged: (value) {
                      if (widget.dataController.getEstado() == false) {
                        setState(() {
                          textoetiqueta =
                              'Por favor ingrese un Valor Correcto'; // Reemplazar la etiqueta por el mensaje de error
                        });
                      } else {
                        setState(() {
                          textoetiqueta = 'Buscar ' +
                              widget.etiqueta
                                  .toString(); // Restaurar la etiqueta original si no hay error
                        });
                      }
                    },
                    readOnly: widget.dataController.estado,
                    validator: (value) {
                      if (widget.dataController.getEstado() == false) {
                        widget.dataController.SetSeleccionadoNoestaOk();
                        return 'Por favor ingrese un Valor Correcto';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      isDense: true,
                      filled: true,
                      border: const OutlineInputBorder(),
                      labelText: widget.etiqueta,
                      hintText: textoetiqueta,
                      prefixIcon: IconButton(
                          splashRadius: 0.4,
                          icon: widget.dataController.estado
                              ? Icon(Icons.check, color: Colors.blue)
                              : Icon(Icons.search, color: Colors.blue),
                          onPressed: () {
                            if (widget.dataController.getEstado() == false) {
                              autoCompleteEditingController!.text = '*';
                              FocusScope.of(context)
                                  .requestFocus(unitCodeCtrlFocusNode);
                            }
                          }),
                      suffixIcon: IconButton(
                          splashRadius: 0.5,
                          icon: const Icon(Icons.clear, color: Colors.blue),
                          onPressed: () {
                            print('//////////// Boton de Clear');
                            widget.dataController.SetSeleccionadoClear();
                            widget.dataController.SetValorEstdoInicial();
                            widget.callBackDependiente(0);
                            widget.dataController.text = 'clear';
                            autoCompleteEditingController!.clear();
                            widget.dataController.SetValorEstadoNoOk();

                            FocusScope.of(context)
                                .requestFocus(unitCodeCtrlFocusNode);
                            setState(() {
                              _showLayoutBuilder = !_showLayoutBuilder;
                            });
                          }),
                    ),
                    controller: textEditingController,
                    focusNode: focusNode,
                    onFieldSubmitted: (value) {
                      //Busca el Campo Digitado en el array y lo asigna.;

                      _datosdgfiltrada = _datos
                          .where((element) =>
                              element.id.toString() == value.toString())
                          .toList();

                      if (_datosdgfiltrada.length != 0) {
                        print('Aqui se selecciono un valor de lista Tamos ok');
                        setState(() {
                          autoCompleteEditingController!.text =
                              _datosdgfiltrada[0].nombre.toString();
                          widget.dataController.text =
                              _datosdgfiltrada[0].nombre.toString();
                          widget.dataController
                              .SetValor(_datosdgfiltrada[0].id);
                          widget.dataController.SetValorEstadoOk();
                          widget.dataController.SetSeleccionadoOk();
                        });
                      } else {
                        setState(() {
                          widget.dataController.SetSeleccionadoNoestaOk();
                          autoCompleteEditingController!.text = "";
                          widget.dataController.SetValorEstadoNoOk();
                          print('---Tamos Mal ***');
                        });
                      }

                      if (value.contains('\t')) {
                        print('tiene tab:' + value);
                      }
                      if (value.contains('\n')) {
                        print('tiene enter:' + value);
                      }
                      onFieldSubmitted();
                    },
                  );
                }, optionsViewBuilder: (context, onselected, _datafiltro) {
                  return SizedBox(
                    height: 200,
                    width: 300,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: Theme.of(context)
                            .dialogBackgroundColor, // Usar el color de fondo del tema

                        child: SizedBox(
                          //altura del espacio del lokup.
                          height: MediaQuery.of(context).size.height * 0.45,
                          width: constraints.maxWidth,
                          child: ListView.separated(
                            controller: my,
                            separatorBuilder:
                                (BuildContext context, int index) => Divider(
                              thickness: 0.5,
                              height: 0.5,
                            ),
                            itemCount: _datafiltro.length,
                            itemBuilder: (BuildContext context, int index2) {
                              return Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.048,
                                child: ListTile(
                                  title: Text(
                                    _datafiltro.elementAt(index2),
                                    style: TextStyle(
                                        color: Colors.blue, fontSize: 12),
                                  ),
                                  onTap: () {
                                    widget.callBackDependiente;
                                    widget.funOnChange;
                                    onselected(_datafiltro.elementAt(index2));
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                }, optionsBuilder: (TextEditingValue value) {
                  print('busqueda 4:' + value.text.toString());

                  if (autoCompleteEditingController!.text == '*') {
                    return _suggestions.toList();
                  }

                  if (value.text.isEmpty) {
                    return [];
                  }
                  print('---en datos generico');
                  _datosdgfiltrada = _datos
                      .where((element) => element.nombre!
                          .toLowerCase()
                          .contains(value.text.toLowerCase().toString()))
                      .toList();

                  for (int i = 0; i < _datosdgfiltrada.length; i++) {
                    print(_datosdgfiltrada[i].nombre);
                  }

                  return _suggestions.where((suggestion) => suggestion
                      .toLowerCase()
                      .contains(value.text.toLowerCase()));
                }, onSelected: (value) {
                  print('/onSelected/' + value);
                  _datosdgfiltrada = _datos
                      .where((element) =>
                          element.nombre!.toLowerCase() ==
                          value.toString().toLowerCase().toString())
                      .toList();
                  if (_datosdgfiltrada.length != 0) {
                    widget.dataController.SetValorEstadoOk();
                    widget.dataController.text =
                        _datosdgfiltrada[0].nombre.toString();
                    widget.dataController.SetValor(_datosdgfiltrada[0].id);
                    print('/onSelected encuentra:/' +
                        _datosdgfiltrada[0].id.toString());
                    widget.dataController.SetValorEstadoOk();
                    widget.callBackDependiente(_datosdgfiltrada[0].id);
                    if (widget.funOnChange != null) {
                      widget.funOnChange!(_datosdgfiltrada[0]);
                    }
                  } else {
                    widget.dataController.SetValorEstadoNoOk();
                  }
                })),
        const SizedBox(
          height: 10,
        ),
      ],
    );
  }
}
