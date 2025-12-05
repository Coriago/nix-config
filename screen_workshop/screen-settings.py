# Installation
# ln -s /home/hp/git/goshansp/infrastructure/files/screen_toggle.py /home/hp/bin/screen_toggle.py

# https://dbus.freedesktop.org/doc/dbus-python/tutorial.html
# https://github.com/GNOME/mutter/blob/b5f99bd12ebc483e682e39c8126a1b51772bc67d/data/dbus-interfaces/org.gnome.Mutter.DisplayConfig.xml
# https://discussion.fedoraproject.org/t/change-scaling-resolution-of-primary-monitor-from-bash-terminal/19892

import dbus
bus = dbus.SessionBus()

display_config_well_known_name = "org.gnome.Mutter.DisplayConfig"
display_config_object_path = "/org/gnome/Mutter/DisplayConfig"

display_config_proxy = bus.get_object(display_config_well_known_name, display_config_object_path)
display_config_interface = dbus.Interface(display_config_proxy, dbus_interface=display_config_well_known_name)

serial, physical_monitors, logical_monitors, properties = display_config_interface.GetCurrentState()

# updated_logical_monitors=[]
# for x, y, scale, transform, primary, linked_monitors_info, props in logical_monitors:
#     physical_monitors_config = []
#     for linked_monitor_connector, linked_monitor_vendor, linked_monitor_product, linked_monitor_serial in linked_monitors_info:
#         for monitor_info, monitor_modes, monitor_properties in physical_monitors:
#             monitor_connector, monitor_vendor, monitor_product, monitor_serial = monitor_info
#             if linked_monitor_connector == monitor_connector:
#                 for mode_id, mode_width, mode_height, mode_refresh, mode_preferred_scale, mode_supported_scales, mode_properties in monitor_modes:
#                     if mode_properties.get("is-current", False): # ( mode_properties provides is-current, is-preferred, is-interlaced, and more)
#                         physical_monitors_config.append(dbus.Struct([monitor_connector, mode_id, {}]))
#                         print(linked_monitor_connector)
#         # reset x for single monitor
#         # if linked_monitor_connector == 'HDMI-2':
#         #   x = 0
#     updated_logical_monitor_struct = dbus.Struct([dbus.Int32(x), dbus.Int32(y), dbus.Double(scale), dbus.UInt32(transform), dbus.Boolean(primary), physical_monitors_config])
#     updated_logical_monitors.append(updated_logical_monitor_struct)

# for updated_logical_monitor in updated_logical_monitors:
#     print(updated_logical_monitor)

# if len(logical_monitors) == 1:
#   updated_logical_monitors = [
#     # Left Monitor
#     dbus.Struct((dbus.Int32(0), dbus.Int32(0), dbus.Double(1.0), dbus.UInt32(0), dbus.Boolean(False), [dbus.Struct((dbus.String('HDMI-1'), dbus.String('1920x1080@60.000'), {}), signature=None)]), signature=None),
#     # Center Monitor
#     dbus.Struct((dbus.Int32(1920), dbus.Int32(0), dbus.Double(1.0), dbus.UInt32(0), dbus.Boolean(True), [dbus.Struct((dbus.String('HDMI-2'), dbus.String('1920x1080@60.000'), {}), signature=None)]), signature=None),
#     # Right Monitor
#     dbus.Struct((dbus.Int32(3840), dbus.Int32(0), dbus.Double(1.0), dbus.UInt32(0), dbus.Boolean(False), [dbus.Struct((dbus.String('DP-2'), dbus.String('1920x1080@60.000'), {}), signature=None)]), signature=None)
#     ]

# if len(logical_monitors) == 3:
#   updated_logical_monitors = [
#     dbus.Struct((dbus.Int32(0), dbus.Int32(0), dbus.Double(1.0), dbus.UInt32(0), dbus.Boolean(True), [dbus.Struct((dbus.String('HDMI-2'), dbus.String('1920x1080@60.000'), {}), signature=None)]), signature=None)
#   ]


updated_logical_monitors = [
    dbus.Struct((dbus.Int32(0), dbus.Int32(0), dbus.Double(1.0), dbus.UInt32(0), dbus.Boolean(True), [
        dbus.Struct((dbus.String('DP-5'), dbus.String('1920x1080@60.000'), {}), signature=None),
        dbus.Struct((dbus.String('HDMI-3'), dbus.String('1920x1080@60.000'), {}), signature=None)
    ]), signature=None),
    dbus.Struct((dbus.Int32(1920), dbus.Int32(0), dbus.Double(1.0), dbus.UInt32(1.0), dbus.Boolean(False), [dbus.Struct((dbus.String('DP-4'), dbus.String('1920x1080@60.000'), {}), signature=None)]), signature=None)
]


properties_to_apply = { "layout_mode": properties.get("layout-mode")}

method = 1 # 2 means show a prompt before applying settings; 1 means instantly apply settings without prompt

display_config_interface.ApplyMonitorsConfig(dbus.UInt32(serial), dbus.UInt32(method), updated_logical_monitors, properties_to_apply)
