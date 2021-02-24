model AHU
  extends AFDD.AHU(
  floor1(duaFanAirHanUnit(mixingBox(ecoCon(redeclare BuildingControlEmulator.Devices.Control.conPIWithOve pI)))),
  floor2(duaFanAirHanUnit(mixingBox(ecoCon(redeclare BuildingControlEmulator.Devices.Control.conPIWithOve pI)))),
  floor3(duaFanAirHanUnit(mixingBox(ecoCon(redeclare BuildingControlEmulator.Devices.Control.conPIWithOve pI)))), 
  floor3(duaFanAirHanUnit(mixingBox(ecoCon(redeclare BuildingControlEmulator.Devices.Control.conPIWithOve pI)))), 
  {% include inner1 %}
  );
  {% include inner2 %}
end AHU;