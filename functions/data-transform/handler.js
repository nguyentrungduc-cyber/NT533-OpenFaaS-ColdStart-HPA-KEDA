'use strict'

const MAX_RECORDS = 10000
const OPS = ['equals', 'gt', 'lt']

const badRequest = (context, msg) => context.status(400).succeed(msg)

function parseBody (event) {
  const type = String(event.headers['content-type'] || '')
  if (type.includes('application/x-www-form-urlencoded')) {
    throw new Error('can header Content-Type: application/json')
  }
  if (typeof event.body === 'string') {
    try {
      return JSON.parse(event.body)
    } catch (e) {
      throw new Error('body khong phai JSON hop le')
    }
  }
  return event.body
}

function renameFields (record, rename) {
  const out = {}
  for (const [key, value] of Object.entries(record)) {
    out[rename[key] || key] = value
  }
  return out
}

function matches (record, filter) {
  const value = record[filter.field]
  if (filter.equals !== undefined) return value === filter.equals
  if (filter.gt !== undefined) return typeof value === 'number' && value > filter.gt
  return typeof value === 'number' && value < filter.lt
}

module.exports = async (event, context) => {
  let data
  try {
    data = parseBody(event)
  } catch (e) {
    return badRequest(context, e.message)
  }
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return badRequest(context, 'can JSON object {"records": [...]}')
  }

  const { records, rename = {}, filter, sum } = data
  if (!Array.isArray(records)) return badRequest(context, 'records phai la mang')
  if (records.length > MAX_RECORDS) return badRequest(context, `toi da ${MAX_RECORDS} records`)
  if (!records.every(r => r && typeof r === 'object' && !Array.isArray(r))) {
    return badRequest(context, 'moi record phai la object')
  }
  if (typeof rename !== 'object' || Array.isArray(rename)) return badRequest(context, 'rename phai la object')
  if (filter !== undefined) {
    const ops = OPS.filter(op => filter && filter[op] !== undefined)
    if (!filter || typeof filter.field !== 'string' || ops.length !== 1) {
      return badRequest(context, 'filter can {"field": "...", va mot trong: equals | gt | lt}')
    }
  }
  if (sum !== undefined && typeof sum !== 'string') return badRequest(context, 'sum phai la ten truong')

  const start = process.hrtime.bigint()

  let out = records.map(r => renameFields(r, rename))
  if (filter) out = out.filter(r => matches(r, filter))
  let total = null
  if (sum) {
    total = out.reduce((acc, r) => acc + (typeof r[sum] === 'number' ? r[sum] : 0), 0)
  }

  const elapsedMs = Number(process.hrtime.bigint() - start) / 1e6

  return context
    .status(200)
    .headers({ 'Content-Type': 'application/json' })
    .succeed({
      count_in: records.length,
      count_out: out.length,
      sum: sum ? { field: sum, total } : null,
      elapsed_ms: Math.round(elapsedMs * 100) / 100,
      records: out
    })
}