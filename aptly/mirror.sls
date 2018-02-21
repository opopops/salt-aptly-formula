{%- from "aptly/map.jinja" import aptly with context %}

include:
  - aptly.install
  - aptly.config

{%- for mirror, params in aptly.get('mirrors', {}).iteritems() %}
  
  {%- for gpg_key in params.get('gpg_keys', []) %}
gpg_import_key_{{mirror}}_{{gpg_key}}:
  cmd.run:
    - name: gpg --no-default-keyring --keyring trustedkeys.gpg --keyserver {{ aptly.gpg.keyserver }} --recv-keys {{ gpg_key }}
    - runas: {{ aptly.user }}
    - unless: gpg --no-default-keyring --keyring trustedkeys.gpg -k {{ gpg_key }}
    - require_in:
      - cmd: aptly_mirror_{{mirror}}
  {%- endfor %}

aptly_mirror_{{mirror}}:
  cmd.run:
    - name: aptly mirror create {% if params.get('udebs', False) %}-with-udebs=true {% endif %}{% if params.get('sources', False) %}-with-sources=true {% endif %}{% if params.get('filters') %}-filter="{{ params.filters|join(' | ') }}" {% endif %}-architectures={{ params.architectures|join(',') }} {{ mirror }} {{ params.source }} {{ params.distribution }} {{ params.components|join(' ') }}
    - runas: {{ aptly.user }}
    - unless: aptly mirror show {{ mirror }}

  {%- if params.get('update', False) == True %}
aptly_mirror_update_{{mirror}}:
  cmd.run:
    - name: aptly mirror update {{ mirror }}
    - runas: {{ aptly.user }}
    - require:
      - cmd: aptly_mirror_{{mirror}}
  {%- endif %}

  {%- if mirror.publish is defined %}
aptly_publish_{{ aptly.mirror[mirror_name].publish }}_snapshot:
  cmd.run:
    - name: aptly publish snapshot -batch=true -gpg-key='{{ aptly.gpg.keypair_id }}' {% if aptly.gpg.get('passphrase', False) %}-passphrase='{{ aptly.gpg.passphrase }}' {% endif %}{{ params.publish }}
    - user: {{ aptly.user }}
  {%- endif %}

{%- endfor %}
