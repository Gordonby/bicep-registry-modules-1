@description('The name of the Automation Account')
param automationAccountName string

@description('Deployment Location')
param location string = resourceGroup().location

@description('Used to reference todays date')
param today string = utcNow('yyyyMMddTHHmmssZ')

@description('The timezone to align schedules to. (Eg. "Europe/London" or "America/Los_Angeles")')
param timezone string = 'Etc/UTC'

@allowed(['Basic', 'Free'])
@description('The Automation Account SKU. See https://learn.microsoft.com/en-us/azure/automation/overview#pricing-for-azure-automation')
param accountSku string = 'Basic'

@description('For Automation job logging')
param loganalyticsWorkspaceId string = ''

@description('Which logging categeories to log')
param diagnosticCategories array = [
  'JobLogs'
  'JobStreams'
  'AuditEvent'
]

type schedule = {
  dayType : 'Day' | 'Weekday'
  
  hour : int
  minute : int
}

@description('Automation Schedules to create')
param schedulesToCreate schedule[] = [
  {
    dayType:'Day'
    hour:9
    minute:0
  }
  {
    dayType:'Weekday'
    hour:9
    minute:0
  }
  {
    dayType:'Day'
    hour:19
    minute:0
  }
  {
    dayType:'Weekday'
    hour:19
    minute:0
  }
  {
    dayType:'Day'
    hour:0
    minute:0
  }
  {
    dayType:'Weekday'
    hour:0
    minute:0
  }
]

type runbookJob = {
  scheduleName: string
  parameters?: object
}

@description('The Runbook-Schedule Jobs to create with workflow specific parameters')
param runbookJobSchedule runbookJob[]

@description('The name of the runbook to create')
param runbookName string

@allowed([
  'GraphPowerShell'
  'Script'
])
@description('The type of runbook that is being imported')
param runbookType string = 'Script'

@description('The URI to import the runbook code from')
param runbookUri string = ''

@description('A description of what the runbook does')
param runbookDescription string = ''

var runbookVersion = '1.0.0.0'
var tomorrow = dateTimeAdd(today, 'P1D','yyyy-MM-dd')
var scheduleNoExpiry = '9999-12-31T23:59:00+00:00'
var workWeek = {weekDays: [
                  'Monday'
                  'Tuesday'
                  'Wednesday'
                  'Thursday'
                  'Friday'
                  ]
                }

resource automationAccount 'Microsoft.Automation/automationAccounts@2022-08-08' = {
  name: automationAccountName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: accountSku
    }
  }
}

resource automationAccountDiagLogging 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if(!empty(loganalyticsWorkspaceId)) {
  name: 'diags'
  scope: automationAccount
  properties: {
    workspaceId: loganalyticsWorkspaceId
    logs: [for diagCategory in diagnosticCategories: {
      category: diagCategory
      enabled: true
    }]
  } 
}

resource schedules 'Microsoft.Automation/automationAccounts/schedules@2022-08-08' = [for schedule in schedulesToCreate : {
  parent: automationAccount
  name: '${schedule.dayType} - ${dateTimeAdd('1970-01-01','P${schedule.hour}H','HH')}:${dateTimeAdd('1970-01-01','P${schedule.hour}H','mm')}'
  properties: {
    startTime: dateTimeAdd(dateTimeAdd(tomorrow,'P${schedule.hour}H'), 'P${schedule.minute}M','yyyy-MM-ddTHH:mm:00+00:00')
    //startTime: '${take(tomorrow,10)}T${schedule.hour}:${schedule.minute}}+00:00'
    //startTime: '${take(tomorrow,10)}T${endsWith(schedule, '9am') ? '09:00:00' : endsWith(schedule, '7pm') ? '19:00:00' : endsWith(schedule, 'Midnight') ? '23:59:59' : '12:00:00'}+00:00'
    expiryTime: scheduleNoExpiry
    interval: 1
    frequency: schedule.dayType == 'Daily' ? 'Day' : 'Week'
    timeZone: timezone
    advancedSchedule: schedule.dayType == 'Weekday' ?  workWeek : {}
  }
}]

resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2022-08-08' = if(!empty(runbookName)) {
  parent: automationAccount
  name: !empty(runbookName) ? runbookName : 'armtemplatevalidationissue'
  location: location
  properties: {
    logVerbose: true
    logProgress: true
    runbookType: runbookType
    publishContentLink: {
      uri: runbookUri
      version: runbookVersion
    }
    description: runbookDescription
  }
}

resource automationJobs 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = [for job in runbookJobSchedule : if(!empty(runbookName)) {
  parent: automationAccount
  name: guid(automationAccount.id, runbook.name, job.schedule)
  properties: {
    schedule: {
      name: job.schedule
    }
    runbook: {
      name: runbook.name
    }
    parameters: job.parameters
  }
  dependsOn: [schedules] //All of the possible schedules
}]

@description('The Automation Account Principal Id')
output automationAccountPrincipalId string = automationAccount.identity.principalId