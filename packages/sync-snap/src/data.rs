use crate::config::Format;
use anyhow::{Context, Result, bail, ensure};
use regex::RegexSet;
use serde_json::{Map, Value};
use std::{
    io::{Seek, SeekFrom, Write},
    process::{Command, Stdio},
};

pub fn parse(bytes: &[u8], format: Format) -> Result<Value> {
    match format {
        Format::Json => serde_json::from_slice(bytes).map_err(|e| {
            // Parser messages can contain actual configuration values.
            anyhow::anyhow!(
                "invalid JSON at line {}, column {} ({:?})",
                e.line(),
                e.column(),
                e.classify()
            )
        }),
        Format::Toml => {
            let text = std::str::from_utf8(bytes).context("TOML must be UTF-8")?;
            let value: toml::Value = toml::from_str(text).map_err(|e: toml::de::Error| {
                anyhow::anyhow!("invalid TOML at byte range {:?}", e.span())
            })?;
            from_toml(value)
        }
        Format::Raw => bail!("raw content does not support structured operations"),
    }
}

fn from_toml(v: toml::Value) -> Result<Value> {
    Ok(match v {
        toml::Value::String(s) => Value::String(s),
        toml::Value::Integer(n) => Value::Number(n.into()),
        toml::Value::Float(n) => Value::Number(serde_json::Number::from_f64(n).context(
            "non-finite TOML floats cannot pass through the JSON data model; use raw copying",
        )?),
        toml::Value::Boolean(v) => Value::Bool(v),
        toml::Value::Datetime(_) => {
            bail!("TOML datetimes require raw copying; refusing to change their type")
        }
        toml::Value::Array(a) => Value::Array(a.into_iter().map(from_toml).collect::<Result<_>>()?),
        toml::Value::Table(m) => Value::Object(
            m.into_iter()
                .map(|(k, v)| Ok((k, from_toml(v)?)))
                .collect::<Result<_>>()?,
        ),
    })
}

fn to_toml(v: &Value) -> Result<toml::Value> {
    Ok(match v {
        Value::Null => bail!("TOML cannot represent null"),
        Value::Bool(b) => toml::Value::Boolean(*b),
        Value::String(s) => toml::Value::String(s.clone()),
        Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                toml::Value::Integer(i)
            } else {
                let text = n.to_string();
                ensure!(
                    text.contains(['.', 'e', 'E']),
                    "integer outside TOML's signed 64-bit range"
                );
                let f = n
                    .as_f64()
                    .filter(|f| f.is_finite())
                    .context("number outside TOML float range")?;
                toml::Value::Float(f)
            }
        }
        Value::Array(a) => toml::Value::Array(a.iter().map(to_toml).collect::<Result<_>>()?),
        Value::Object(m) => toml::Value::Table(
            m.iter()
                .map(|(k, v)| Ok((k.clone(), to_toml(v)?)))
                .collect::<Result<_>>()?,
        ),
    })
}

pub fn encode(v: &Value, format: Format) -> Result<Vec<u8>> {
    match format {
        Format::Json => {
            let mut b = serde_json::to_vec_pretty(v)?;
            b.push(b'\n');
            Ok(b)
        }
        Format::Toml => {
            ensure!(v.is_object(), "TOML output must be an object");
            toml::to_string_pretty(&to_toml(v)?)
                .map(String::into_bytes)
                .map_err(|_| anyhow::anyhow!("cannot serialize TOML output"))
        }
        Format::Raw => bail!("structured data cannot be serialized as raw content"),
    }
}

/// Objects merge recursively; every other value (including arrays/null) is atomic.
pub fn merge(dst: &mut Value, src: Value, replace: bool) {
    match (dst, src) {
        (Value::Object(dst), Value::Object(src)) => {
            for (key, value) in src {
                match dst.get_mut(&key) {
                    Some(old) => merge(old, value, replace),
                    None => {
                        dst.insert(key, value);
                    }
                }
            }
        }
        (dst, src) if replace => *dst = src,
        _ => (),
    }
}

pub struct Pruner {
    keys: RegexSet,
    values: RegexSet,
}
impl Pruner {
    pub fn new(keys: &[String], values: &[String]) -> Result<Self> {
        Ok(Self {
            keys: RegexSet::new(keys).map_err(|_| anyhow::anyhow!("invalid key-pruning regex"))?,
            values: RegexSet::new(values)
                .map_err(|_| anyhow::anyhow!("invalid value-pruning regex"))?,
        })
    }

    pub fn apply(&self, v: Value) -> Value {
        // No match is applied to the root itself. A dropped root array becomes [].
        let array = v.is_array();
        self.walk(v, "").0.unwrap_or_else(|| {
            if array {
                Value::Array(vec![])
            } else {
                Value::Object(Map::new())
            }
        })
    }

    fn walk(&self, v: Value, path: &str) -> (Option<Value>, bool) {
        if !path.is_empty() && self.keys.is_match(path) {
            return (None, true);
        }
        match v {
            Value::Object(m) => {
                let mut out = Map::new();
                let mut changed = false;
                for (key, child) in m {
                    let escaped = key.replace('\\', "\\\\").replace('.', "\\.");
                    let subpath = if path.is_empty() {
                        escaped
                    } else {
                        format!("{path}.{escaped}")
                    };
                    let (clean, pruned) = self.walk(child, &subpath);
                    changed |= pruned;
                    if let Some(value) = clean {
                        out.insert(key, value);
                    }
                }
                (Some(Value::Object(out)), changed)
            }
            Value::Array(a) => {
                let mut out = Vec::with_capacity(a.len());
                for (i, child) in a.into_iter().enumerate() {
                    let subpath = if path.is_empty() {
                        i.to_string()
                    } else {
                        format!("{path}.{i}")
                    };
                    let (clean, changed) = self.walk(child, &subpath);
                    if changed {
                        return (None, true);
                    }
                    if let Some(value) = clean {
                        out.push(value);
                    }
                }
                (Some(Value::Array(out)), false)
            }
            scalar => {
                let text = match &scalar {
                    Value::String(s) => s.clone(),
                    _ => scalar.to_string(),
                };
                if self.values.is_match(&text) {
                    (None, true)
                } else {
                    (Some(scalar), false)
                }
            }
        }
    }
}

pub fn transform(mut value: Value, filters: &[String], jq: &str) -> Result<Value> {
    for (index, filter) in filters.iter().enumerate() {
        // An anonymous file avoids pipe deadlocks on large input/output and keeps
        // intermediate configuration off named paths. jq stderr can contain secrets.
        let mut input = tempfile::tempfile().context("create jq input")?;
        serde_json::to_writer(&mut input, &value)?;
        input.flush()?;
        input.seek(SeekFrom::Start(0))?;
        let output = Command::new(jq)
            .args(["-c", "--", filter])
            .stdin(input)
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .output()
            .context("execute jq")?;
        ensure!(
            output.status.success(),
            "jq transform {} failed ({}); stderr suppressed to avoid logging configuration",
            index + 1,
            output.status
        );
        let mut stream = serde_json::Deserializer::from_slice(&output.stdout).into_iter::<Value>();
        value = stream
            .next()
            .context("jq must return one document, not zero")?
            .map_err(|_| anyhow::anyhow!("jq returned invalid JSON"))?;
        ensure!(
            stream.next().is_none(),
            "jq must return exactly one document"
        );
        ensure!(
            value.is_object() || value.is_array(),
            "jq must return an object or array document"
        );
    }
    Ok(value)
}
