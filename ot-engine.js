/**
 * A small string OT implementation. Operations are arrays of retain, delete,
 * and insert components. Concurrent inserts at the same position are ordered
 * by client id so every participant converges on the same document.
 */

export function retain(count) {
  return { type: 'retain', count };
}

export function remove(count) {
  return { type: 'delete', count };
}

export function insert(text) {
  return { type: 'insert', text };
}

export function normalize(operation) {
  const result = [];
  for (const component of operation) {
    if (component.type === 'retain' && component.count > 0) {
      if (result.at(-1)?.type === 'retain') result.at(-1).count += component.count;
      else result.push({ type: 'retain', count: component.count });
    } else if (component.type === 'delete' && component.count > 0) {
      if (result.at(-1)?.type === 'delete') result.at(-1).count += component.count;
      else result.push({ type: 'delete', count: component.count });
    } else if (component.type === 'insert' && component.text) {
      if (result.at(-1)?.type === 'insert') result.at(-1).text += component.text;
      else result.push({ type: 'insert', text: component.text });
    }
  }
  return result;
}

export function applyOperation(text, operation) {
  let cursor = 0;
  let output = '';
  for (const component of normalize(operation)) {
    if (component.type === 'retain') {
      if (cursor + component.count > text.length) throw new RangeError('Retain exceeds document length');
      output += text.slice(cursor, cursor + component.count);
      cursor += component.count;
    } else if (component.type === 'delete') {
      if (cursor + component.count > text.length) throw new RangeError('Delete exceeds document length');
      cursor += component.count;
    } else {
      output += component.text;
    }
  }
  if (cursor !== text.length) throw new RangeError('Operation does not consume the document');
  return output;
}

export function invertOperation(operation, text) {
  let cursor = 0;
  const inverse = [];
  for (const component of normalize(operation)) {
    if (component.type === 'retain') {
      inverse.push(retain(component.count));
      cursor += component.count;
    } else if (component.type === 'delete') {
      inverse.push(insert(text.slice(cursor, cursor + component.count)));
      cursor += component.count;
    } else {
      inverse.push(remove(component.text.length));
    }
  }
  return normalize(inverse);
}

function take(operation, amount) {
  const component = operation[0];
  if (!component) return null;
  if (component.type === 'insert') {
    const part = insert(component.text.slice(0, amount));
    component.text = component.text.slice(amount);
    if (!component.text) operation.shift();
    return part;
  }
  const part = { type: component.type, count: amount };
  component.count -= amount;
  if (!component.count) operation.shift();
  return part;
}

/** Transform operation A against operation B. */
export function transform(a, b, clientA = 'a', clientB = 'b') {
  const left = normalize(a).map((component) => ({ ...component }));
  const right = normalize(b).map((component) => ({ ...component }));
  const aPrime = [];
  const bPrime = [];
  let tieOrder = clientA < clientB;

  while (left.length || right.length) {
    if (left[0]?.type === 'insert' && right[0]?.type === 'insert') {
      if (tieOrder) {
        aPrime.push(take(left, left[0].text.length));
        bPrime.push(retain(left[0]?.text?.length ?? 0));
      } else {
        aPrime.push(retain(right[0].text.length));
        bPrime.push(take(right, right[0].text.length));
      }
      continue;
    }
    if (left[0]?.type === 'insert') {
      const part = take(left, left[0].text.length);
      aPrime.push(part);
      bPrime.push(retain(part.text.length));
      continue;
    }
    if (right[0]?.type === 'insert') {
      const part = take(right, right[0].text.length);
      aPrime.push(retain(part.text.length));
      bPrime.push(part);
      continue;
    }
    if (!left.length || !right.length) break;
    const amount = Math.min(left[0].count, right[0].count);
    const aPart = take(left, amount);
    const bPart = take(right, amount);
    if (aPart.type === 'retain' && bPart.type === 'retain') {
      aPrime.push(retain(amount));
      bPrime.push(retain(amount));
    } else if (aPart.type === 'delete' && bPart.type === 'delete') {
      // Both operations remove the same source range.
    } else if (aPart.type === 'delete') {
      aPrime.push(remove(amount));
    } else {
      bPrime.push(remove(amount));
    }
  }
  return [normalize(aPrime), normalize(bPrime)];
}

export function operationFromChange(previous, next) {
  let start = 0;
  while (start < previous.length && start < next.length && previous[start] === next[start]) start += 1;
  let endPrevious = previous.length;
  let endNext = next.length;
  while (endPrevious > start && endNext > start && previous[endPrevious - 1] === next[endNext - 1]) {
    endPrevious -= 1;
    endNext -= 1;
  }
  const operation = [];
  if (start) operation.push(retain(start));
  if (endPrevious > start) operation.push(remove(endPrevious - start));
  if (endNext > start) operation.push(insert(next.slice(start, endNext)));
  if (endPrevious < previous.length) operation.push(retain(previous.length - endPrevious));
  return normalize(operation);
}
