/**
 * Extracts student name from the raw HTML.
 */
function extractStudentName(html) {
  // Try pattern that skips colon separator: Student Name</td>...<td>actual name</td>
  let match = html.match(/Student Name<\/td>[\s\S]*?<td[^>]*>([^<:]+)<\/td>/i);
  if (match) return match[1].trim();
  // Try pattern like lblStudentName">John Doe
  match = html.match(/lblStudentName["'][^>]*>([^<]+)</i);
  if (match) return match[1].trim();
  // Try "Student Name" or "Name" label pattern
  match = html.match(/Student Name\s*:\s*([^<]+)/i);
  if (match) return match[1].trim();
  match = html.match(/Name\s*:\s*([^<]+)/i);
  if (match) return match[1].trim();
  return '';
}

/**
 * Parse HTML attendance table (id="tblReport") from university portal.
 * Returns object with overallPercentage, totalClasses, totalAttended, subjects, studentName, hasReport.
 */
export function parseAttendanceHtml(html) {
  // Locate tblReport - match single or double quotes
  let reportStart = html.indexOf('id="tblReport"');
  if (reportStart === -1) reportStart = html.indexOf("id='tblReport'");
  if (reportStart === -1) {
    return { hasReport: false, subjects: [], overallPercentage: 0, totalClasses: 0, totalAttended: 0, studentName: extractStudentName(html) };
  }

  // Find the data table - skip the first four tables (outer wrapper, header, student info, and one more)
  // then grab the fifth <table> which is the actual attendance data table
  let pos = reportStart;
  let tableStart = -1;
  for (let i = 0; i < 5; i++) {
    pos = html.indexOf('<table', pos + 1);
    if (pos === -1) break;
    tableStart = pos;
  }

  if (tableStart === -1) {
    return { hasReport: false, subjects: [], overallPercentage: 0, totalClasses: 0, totalAttended: 0, studentName: extractStudentName(html) };
  }

  // Use lastIndexOf to capture full nested table content
  let tableEnd = html.lastIndexOf('</table>');
  if (tableEnd === -1) tableEnd = html.length;
  const tableHtml = html.substring(tableStart, tableEnd + 8);

  // Collect all rows (<tr>)
  const rows = [];
  const trRegex = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  let trMatch;
  while ((trMatch = trRegex.exec(tableHtml)) !== null) {
    rows.push(trMatch[1]);
  }
  console.log('[PARSER] tableStart:', tableStart, 'rows:', rows.length);
  console.log('[PARSER] row0:', rows[0]?.substring(0, 150));
  console.log('[PARSER] row1:', rows[1]?.substring(0, 150));
  if (rows.length < 2) return { hasReport: false, subjects: [], overallPercentage: 0, totalClasses: 0, totalAttended: 0, studentName: '' };

  // Extract student name using dedicated function
  const studentName = extractStudentName(html);

  // Parse header row (first row with <th> or first row)
  let headerCols = [];
  const headerCells = rows[0].match(/<t[hd][^>]*>([\s\S]*?)<\/t[hd]>/gi) || [];
  for (let cell of headerCells) {
    const text = cell.replace(/<[^>]+>/g, '').trim().toLowerCase();
    headerCols.push(text);
  }

  // Map column indices
  const subjIdx = headerCols.findIndex(c => c.includes('subject') || c.includes('course') || c.includes('paper'));
  const heldIdx = headerCols.findIndex(c => c.includes('held'));
  // Fix: match 'attend' but not 'attendance' — catches both 'Attend' and 'Attended'
  const attendedIdx = headerCols.findIndex(c => c.includes('attend') && !c.includes('attendance'));
  const percentIdx = headerCols.findIndex(c => c === '%' || c.includes('percent'));

  if (subjIdx === -1 || (heldIdx === -1 && percentIdx === -1)) {
    return { hasReport: false, subjects: [], overallPercentage: 0, totalClasses: 0, totalAttended: 0, studentName: extractStudentName(html) };
  }

  const subjects = [];
  let totalHeld = 0, totalAttended = 0;
  let hasReport = false;

  // Process data rows (skip header)
  for (let i = 1; i < rows.length; i++) {
    const cells = rows[i].match(/<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi) || [];
    if (cells.length === 0) continue;

    const subjectName = cells[subjIdx] ? cells[subjIdx].replace(/<[^>]+>/g, '').trim() : '';
    // Skip empty, header-like, or pure-number subjects
    if (!subjectName) continue;
    if (!/[a-zA-Z]/.test(subjectName)) continue;
    if (/^(subject|sr|sl)/i.test(subjectName)) continue;

    // Check if this is a "total" summary row
    if (subjectName.toLowerCase() === 'total') {
      const totalHeldCell = heldIdx !== -1 && cells[heldIdx] ? cells[heldIdx].replace(/<[^>]+>/g, '').trim() : '';
      const totalAttendedCell = attendedIdx !== -1 && cells[attendedIdx] ? cells[attendedIdx].replace(/<[^>]+>/g, '').trim() : '';
      totalHeld = parseInt(totalHeldCell, 10) || totalHeld;
      totalAttended = parseInt(totalAttendedCell, 10) || totalAttended;
      hasReport = true;
      continue;
    }

    const held = heldIdx !== -1 ? parseInt(cells[heldIdx]?.replace(/<[^>]+>/g, '').trim(), 10) : 0;
    const attended = attendedIdx !== -1 ? parseInt(cells[attendedIdx]?.replace(/<[^>]+>/g, '').trim(), 10) : 0;
    const percentText = percentIdx !== -1 && cells[percentIdx] ? cells[percentIdx].replace(/<[^>]+>/g, '').trim() : '';
    let percentage = parseFloat(percentText);
    if (isNaN(percentage) && held > 0) percentage = (attended / held) * 100;
    if (isNaN(percentage)) percentage = 0;

    subjects.push({
      subject: subjectName,
      totalClasses: held,
      attendedClasses: attended,
      percentage: Math.round(percentage * 10) / 10
    });
  }

  // If no total row found, compute from subjects
  if (!hasReport && subjects.length > 0) {
    totalHeld = subjects.reduce((s, x) => s + x.totalClasses, 0);
    totalAttended = subjects.reduce((s, x) => s + x.attendedClasses, 0);
    hasReport = true;
  }

  const overallPercentage = totalHeld > 0 ? (totalAttended / totalHeld) * 100 : 0;
  return {
    overallPercentage: Math.round(overallPercentage * 10) / 10,
    totalClasses: totalHeld,
    totalAttended: totalAttended,
    subjects,
    studentName: studentName || extractStudentName(html),
    hasReport
  };
}
